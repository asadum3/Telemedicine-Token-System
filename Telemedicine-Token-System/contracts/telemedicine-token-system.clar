;; Telemedicine Token System - Decentralized Healthcare Consultations
;; Version: 1.0.0
;; Author: Smart Contract Developer

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_CONSULTATION_COMPLETE (err u410))
(define-constant ERR_CONSULTATION_ACTIVE (err u411))
(define-constant ERR_INVALID_STATUS (err u412))

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Token parameters
(define-fungible-token telemed-token)
(define-constant TOKEN_DECIMALS u6)
(define-constant INITIAL_SUPPLY u1000000000000) ;; 1M tokens with 6 decimals

;; Fee structure
(define-constant CONSULTATION_BASE_FEE u50000000) ;; 50 tokens
(define-constant PLATFORM_FEE_PERCENT u5) ;; 5%
(define-constant SPECIALIST_BONUS_PERCENT u20) ;; 20% bonus for specialists

;; Data maps
(define-map doctors
    principal
    {
        name: (string-utf8 100),
        specialty: (string-utf8 50),
        rating: uint,
        total-consultations: uint,
        is-specialist: bool,
        hourly-rate: uint,
        is-active: bool
    }
)

(define-map patients
    principal
    {
        name: (string-utf8 100),
        medical-record-hash: (string-utf8 64),
        total-consultations: uint
    }
)

(define-map consultations
    uint
    {
        patient: principal,
        doctor: principal,
        consultation-fee: uint,
        status: (string-ascii 20),
        start-time: uint,
        end-time: (optional uint),
        rating: (optional uint),
        medical-notes-hash: (optional (string-utf8 64))
    }
)

(define-map doctor-earnings principal uint)
(define-map consultation-counter uint uint)

;; Initialize consultation counter
(map-set consultation-counter u0 u0)

;; Public functions

;; Initialize contract and mint initial supply
(define-public (initialize-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (try! (ft-mint? telemed-token INITIAL_SUPPLY CONTRACT_OWNER))
        (ok true)
    )
)

;; Register as a doctor
(define-public (register-doctor 
    (name (string-utf8 100))
    (specialty (string-utf8 50))
    (hourly-rate uint)
    (is-specialist bool)
)
    (begin
        (asserts! (is-none (map-get? doctors tx-sender)) ERR_ALREADY_EXISTS)
        (asserts! (> hourly-rate u0) ERR_INVALID_AMOUNT)
        (map-set doctors tx-sender {
            name: name,
            specialty: specialty,
            rating: u5000, ;; Start with 5.0 rating (scaled by 1000)
            total-consultations: u0,
            is-specialist: is-specialist,
            hourly-rate: hourly-rate,
            is-active: true
        })
        (map-set doctor-earnings tx-sender u0)
        (ok true)
    )
)

;; Register as a patient
(define-public (register-patient 
    (name (string-utf8 100))
    (medical-record-hash (string-utf8 64))
)
    (begin
        (asserts! (is-none (map-get? patients tx-sender)) ERR_ALREADY_EXISTS)
        (map-set patients tx-sender {
            name: name,
            medical-record-hash: medical-record-hash,
            total-consultations: u0
        })
        (ok true)
    )
)

;; Book consultation
(define-public (book-consultation (doctor principal) (estimated-duration uint))
    (let (
        (doctor-info (unwrap! (map-get? doctors doctor) ERR_NOT_FOUND))
        (patient-info (unwrap! (map-get? patients tx-sender) ERR_NOT_FOUND))
        (consultation-id (+ (unwrap-panic (map-get? consultation-counter u0)) u1))
        (consultation-fee (calculate-consultation-fee doctor estimated-duration))
    )
        (asserts! (get is-active doctor-info) ERR_UNAUTHORIZED)
        (asserts! (>= (ft-get-balance telemed-token tx-sender) consultation-fee) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer tokens to escrow (contract)
        (try! (ft-transfer? telemed-token consultation-fee tx-sender (as-contract tx-sender)))
        
        ;; Create consultation record
        (map-set consultations consultation-id {
            patient: tx-sender,
            doctor: doctor,
            consultation-fee: consultation-fee,
            status: "booked",
            start-time: block-height,
            end-time: none,
            rating: none,
            medical-notes-hash: none
        })
        
        ;; Update consultation counter
        (map-set consultation-counter u0 consultation-id)
        
        (ok consultation-id)
    )
)

;; Start consultation (doctor only)
(define-public (start-consultation (consultation-id uint))
    (let (
        (consultation (unwrap! (map-get? consultations consultation-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get doctor consultation)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status consultation) "booked") ERR_INVALID_STATUS)
        
        (map-set consultations consultation-id 
            (merge consultation { status: "active", start-time: block-height })
        )
        (ok true)
    )
)

;; End consultation and add medical notes
(define-public (end-consultation 
    (consultation-id uint)
    (medical-notes-hash (string-utf8 64))
)
    (let (
        (consultation (unwrap! (map-get? consultations consultation-id) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get doctor consultation)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status consultation) "active") ERR_INVALID_STATUS)
        
        (map-set consultations consultation-id 
            (merge consultation { 
                status: "completed",
                end-time: (some block-height),
                medical-notes-hash: (some medical-notes-hash)
            })
        )
        
        ;; Process payment to doctor
        (process-consultation-payment consultation-id)
        
        (ok true)
    )
)

;; Rate consultation (patient only)
(define-public (rate-consultation (consultation-id uint) (rating uint))
    (let (
        (consultation (unwrap! (map-get? consultations consultation-id) ERR_NOT_FOUND))
        (doctor (get doctor consultation))
        (doctor-info (unwrap! (map-get? doctors doctor) ERR_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get patient consultation)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status consultation) "completed") ERR_INVALID_STATUS)
        (asserts! (and (>= rating u1000) (<= rating u5000)) ERR_INVALID_AMOUNT) ;; 1.0 to 5.0 scaled
        (asserts! (is-none (get rating consultation)) ERR_ALREADY_EXISTS)
        
        ;; Update consultation rating
        (map-set consultations consultation-id 
            (merge consultation { rating: (some rating) })
        )
        
        ;; Update doctor stats
        (let (
            (total-consultations (+ (get total-consultations doctor-info) u1))
            (new-rating (update-doctor-rating doctor rating))
        )
            (map-set doctors doctor
                (merge doctor-info {
                    rating: new-rating,
                    total-consultations: total-consultations
                })
            )
        )
        
        ;; Update patient stats
        (let (
            (patient-info (unwrap! (map-get? patients tx-sender) ERR_NOT_FOUND))
        )
            (map-set patients tx-sender
                (merge patient-info {
                    total-consultations: (+ (get total-consultations patient-info) u1)
                })
            )
        )
        
        (ok true)
    )
)

;; Withdraw earnings (doctor only)
(define-public (withdraw-earnings)
    (let (
        (doctor-info (unwrap! (map-get? doctors tx-sender) ERR_NOT_FOUND))
        (earnings (default-to u0 (map-get? doctor-earnings tx-sender)))
    )
        (asserts! (> earnings u0) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer earnings from contract to doctor
        (try! (as-contract (ft-transfer? telemed-token earnings (as-contract tx-sender) tx-sender)))
        
        ;; Reset earnings
        (map-set doctor-earnings tx-sender u0)
        
        (ok earnings)
    )
)

;; Purchase tokens (for patients)
(define-public (purchase-tokens (amount uint))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        ;; In a real implementation, this would integrate with STX payments
        (try! (as-contract (ft-transfer? telemed-token amount (as-contract tx-sender) tx-sender)))
        (ok true)
    )
)

;; Private functions

;; Calculate consultation fee based on doctor rate and duration
(define-private (calculate-consultation-fee (doctor principal) (duration uint))
    (let (
        (doctor-info (unwrap-panic (map-get? doctors doctor)))
        (base-fee (* (get hourly-rate doctor-info) duration))
        (specialist-bonus (if (get is-specialist doctor-info)
            (/ (* base-fee SPECIALIST_BONUS_PERCENT) u100)
            u0
        ))
    )
        (+ base-fee specialist-bonus)
    )
)

;; Process payment after consultation completion
(define-private (process-consultation-payment (consultation-id uint))
    (let (
        (consultation (unwrap-panic (map-get? consultations consultation-id)))
        (doctor (get doctor consultation))
        (consultation-fee (get consultation-fee consultation))
        (platform-fee (/ (* consultation-fee PLATFORM_FEE_PERCENT) u100))
        (doctor-payment (- consultation-fee platform-fee))
        (current-earnings (default-to u0 (map-get? doctor-earnings doctor)))
    )
        ;; Add to doctor earnings
        (map-set doctor-earnings doctor (+ current-earnings doctor-payment))
        
        ;; Platform fee stays in contract
        doctor-payment
    )
)

;; Update doctor rating with weighted average
(define-private (update-doctor-rating (doctor principal) (new-rating uint))
    (let (
        (doctor-info (unwrap-panic (map-get? doctors doctor)))
        (current-rating (get rating doctor-info))
        (total-consultations (get total-consultations doctor-info))
    )
        (if (is-eq total-consultations u0)
            new-rating
            (/ (+ (* current-rating total-consultations) new-rating) (+ total-consultations u1))
        )
    )
)

;; Read-only functions

;; Get doctor info
(define-read-only (get-doctor-info (doctor principal))
    (map-get? doctors doctor)
)

;; Get patient info
(define-read-only (get-patient-info (patient principal))
    (map-get? patients patient)
)

;; Get consultation details
(define-read-only (get-consultation (consultation-id uint))
    (map-get? consultations consultation-id)
)

;; Get doctor earnings
(define-read-only (get-doctor-earnings (doctor principal))
    (default-to u0 (map-get? doctor-earnings doctor))
)

;; Get token balance
(define-read-only (get-balance (user principal))
    (ft-get-balance telemed-token user)
)

;; Get total supply
(define-read-only (get-total-supply)
    (ft-get-supply telemed-token)
)

;; Get current consultation counter
(define-read-only (get-consultation-counter)
    (default-to u0 (map-get? consultation-counter u0))
)