;; Emergency Override System Contract
;; Handles critical medical situations requiring immediate treatment without standard consent

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_EMERGENCY_NOT_FOUND (err u201))
(define-constant ERR_INSUFFICIENT_AUTHORIZATION (err u202))
(define-constant ERR_EMERGENCY_EXPIRED (err u203))
(define-constant ERR_INVALID_EMERGENCY_LEVEL (err u204))
(define-constant ERR_ALREADY_AUTHORIZED (err u205))
(define-constant ERR_PATIENT_NOT_FOUND (err u206))
(define-constant ERR_OVERRIDE_ALREADY_EXISTS (err u207))

;; Reference to main contract
(define-constant MAIN_CONTRACT .Medconsent)

;; Time constants (in Stacks blocks)
(define-constant EMERGENCY_DURATION_CRITICAL u144)   ;; 24 hours
(define-constant EMERGENCY_DURATION_URGENT u72)     ;; 12 hours
(define-constant EMERGENCY_DURATION_STANDARD u36)   ;; 6 hours

;; Emergency levels and required authorizations
(define-constant CRITICAL_LEVEL u3)    ;; Requires 2 providers
(define-constant URGENT_LEVEL u2)      ;; Requires 1 senior provider
(define-constant STANDARD_LEVEL u1)    ;; Requires 1 provider

;; Emergency override records
(define-map emergency-overrides
  { override-id: uint }
  {
    patient-id: principal,
    initiating-provider: principal,
    emergency-level: uint,
    treatment-type: (string-ascii 200),
    medical-justification: (string-ascii 500),
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    required-authorizations: uint,
    received-authorizations: uint,
    is-active: bool
  }
)

;; Provider authorizations for emergency overrides
(define-map override-authorizations
  { override-id: uint, provider-id: principal }
  {
    authorization-timestamp: uint,
    provider-role: (string-ascii 50),
    authorization-notes: (string-ascii 300),
    risk-assessment: uint
  }
)

;; Emergency contact notifications
(define-map emergency-notifications
  { override-id: uint }
  {
    contact-attempted: bool,
    contact-successful: bool,
    contact-timestamp: (optional uint),
    contact-method: (optional (string-ascii 50)),
    family-consent: (optional bool),
    notification-notes: (optional (string-ascii 200))
  }
)

;; Post-emergency validation tracking
(define-map post-emergency-validation
  { override-id: uint }
  {
    patient-notified: bool,
    patient-consent-obtained: (optional bool),
    validation-timestamp: (optional uint),
    patient-feedback: (optional (string-ascii 300)),
    ethics-review-required: bool,
    ethics-review-completed: bool,
    final-disposition: (optional (string-ascii 100))
  }
)

;; Global state
(define-data-var next-override-id uint u1)

;; Create emergency override request
(define-public (create-emergency-override 
  (patient-id principal) 
  (emergency-level uint) 
  (treatment-type (string-ascii 200)) 
  (medical-justification (string-ascii 500)))
  (let (
    (override-id (var-get next-override-id))
    (provider-verified (contract-call? MAIN_CONTRACT is-provider-verified tx-sender))
    (patient-exists (is-some (contract-call? MAIN_CONTRACT get-patient patient-id)))
    (required-auth (get-required-authorizations emergency-level))
    (duration (get-emergency-duration emergency-level))
  )
    (if (and 
      provider-verified 
      patient-exists 
      (>= emergency-level STANDARD_LEVEL) 
      (<= emergency-level CRITICAL_LEVEL))
      (begin
        (map-set emergency-overrides
          { override-id: override-id }
          {
            patient-id: patient-id,
            initiating-provider: tx-sender,
            emergency-level: emergency-level,
            treatment-type: treatment-type,
            medical-justification: medical-justification,
            created-at: stacks-block-height,
            expires-at: (+ stacks-block-height duration),
            status: "PENDING",
            required-authorizations: required-auth,
            received-authorizations: u0,
            is-active: true
          }
        )
        ;; Initialize notification record
        (map-set emergency-notifications
          { override-id: override-id }
          {
            contact-attempted: false,
            contact-successful: false,
            contact-timestamp: none,
            contact-method: none,
            family-consent: none,
            notification-notes: none
          }
        )
        ;; Initialize validation record
        (map-set post-emergency-validation
          { override-id: override-id }
          {
            patient-notified: false,
            patient-consent-obtained: none,
            validation-timestamp: none,
            patient-feedback: none,
            ethics-review-required: (>= emergency-level URGENT_LEVEL),
            ethics-review-completed: false,
            final-disposition: none
          }
        )
        (var-set next-override-id (+ override-id u1))
        (ok override-id)
      )
      ERR_UNAUTHORIZED
    )
  )
)

;; Authorize emergency override
(define-public (authorize-emergency-override 
  (override-id uint) 
  (provider-role (string-ascii 50)) 
  (authorization-notes (string-ascii 300)) 
  (risk-assessment uint))
  (match (map-get? emergency-overrides { override-id: override-id })
    override-data
    (let (
      (provider-verified (contract-call? MAIN_CONTRACT is-provider-verified tx-sender))
      (already-authorized (is-some (map-get? override-authorizations { override-id: override-id, provider-id: tx-sender })))
      (is-not-initiator (not (is-eq tx-sender (get initiating-provider override-data))))
      (not-expired (> (get expires-at override-data) stacks-block-height))
      (is-pending (is-eq (get status override-data) "PENDING"))
      (current-auth (get received-authorizations override-data))
      (required-auth (get required-authorizations override-data))
    )
      (if (and provider-verified is-not-initiator (not already-authorized) not-expired is-pending)
        (begin
          ;; Add authorization
          (map-set override-authorizations
            { override-id: override-id, provider-id: tx-sender }
            {
              authorization-timestamp: stacks-block-height,
              provider-role: provider-role,
              authorization-notes: authorization-notes,
              risk-assessment: risk-assessment
            }
          )
          ;; Update override record
          (let ((new-auth-count (+ current-auth u1)))
            (map-set emergency-overrides
              { override-id: override-id }
              (merge override-data {
                received-authorizations: new-auth-count,
                status: (if (>= new-auth-count required-auth) "AUTHORIZED" "PENDING")
              })
            )
            (ok new-auth-count)
          )
        )
        ERR_UNAUTHORIZED
      )
    )
    ERR_EMERGENCY_NOT_FOUND
  )
)

;; Execute emergency treatment (when fully authorized)
(define-public (execute-emergency-treatment 
  (override-id uint) 
  (treatment-notes (string-ascii 500)))
  (match (map-get? emergency-overrides { override-id: override-id })
    override-data
    (if (and 
      (is-eq tx-sender (get initiating-provider override-data))
      (is-eq (get status override-data) "AUTHORIZED")
      (> (get expires-at override-data) stacks-block-height))
      (begin
        ;; Update status to executed
        (map-set emergency-overrides
          { override-id: override-id }
          (merge override-data {
            status: "EXECUTED"
          })
        )
        ;; Log execution in main contract audit trail
        (try! (contract-call? MAIN_CONTRACT log-data-access 
          (get patient-id override-data)
          "EMERGENCY_TREATMENT"
          (get treatment-type override-data)
          (list "emergency-override" "critical-care")))
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_EMERGENCY_NOT_FOUND
  )
)

;; Update emergency contact notification
(define-public (update-emergency-notification 
  (override-id uint) 
  (contact-successful bool) 
  (contact-method (string-ascii 50)) 
  (family-consent (optional bool)) 
  (notes (string-ascii 200)))
  (match (map-get? emergency-overrides { override-id: override-id })
    override-data
    (if (contract-call? MAIN_CONTRACT is-provider-verified tx-sender)
      (begin
        (map-set emergency-notifications
          { override-id: override-id }
          {
            contact-attempted: true,
            contact-successful: contact-successful,
            contact-timestamp: (some stacks-block-height),
            contact-method: (some contact-method),
            family-consent: family-consent,
            notification-notes: (some notes)
          }
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_EMERGENCY_NOT_FOUND
  )
)

;; Complete post-emergency validation
(define-public (complete-post-emergency-validation 
  (override-id uint) 
  (patient-consent-obtained bool) 
  (patient-feedback (string-ascii 300)) 
  (final-disposition (string-ascii 100)))
  (match (map-get? emergency-overrides { override-id: override-id })
    override-data
    (if (is-eq tx-sender (get initiating-provider override-data))
      (begin
        (map-set post-emergency-validation
          { override-id: override-id }
          {
            patient-notified: true,
            patient-consent-obtained: (some patient-consent-obtained),
            validation-timestamp: (some stacks-block-height),
            patient-feedback: (some patient-feedback),
            ethics-review-required: (>= (get emergency-level override-data) URGENT_LEVEL),
            ethics-review-completed: false,
            final-disposition: (some final-disposition)
          }
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_EMERGENCY_NOT_FOUND
  )
)

;; Helper functions
(define-private (get-required-authorizations (emergency-level uint))
  (if (is-eq emergency-level CRITICAL_LEVEL) u2
    (if (is-eq emergency-level URGENT_LEVEL) u1 u1))
)

(define-private (get-emergency-duration (emergency-level uint))
  (if (is-eq emergency-level CRITICAL_LEVEL) EMERGENCY_DURATION_CRITICAL
    (if (is-eq emergency-level URGENT_LEVEL) EMERGENCY_DURATION_URGENT EMERGENCY_DURATION_STANDARD))
)

;; Read-only functions
(define-read-only (get-emergency-override (override-id uint))
  (map-get? emergency-overrides { override-id: override-id })
)

(define-read-only (get-override-authorization (override-id uint) (provider-id principal))
  (map-get? override-authorizations { override-id: override-id, provider-id: provider-id })
)

(define-read-only (get-emergency-notification (override-id uint))
  (map-get? emergency-notifications { override-id: override-id })
)

(define-read-only (get-post-emergency-validation (override-id uint))
  (map-get? post-emergency-validation { override-id: override-id })
)

(define-read-only (check-override-authorization (override-id uint))
  (match (map-get? emergency-overrides { override-id: override-id })
    override-data
    {
      is-authorized: (>= (get received-authorizations override-data) (get required-authorizations override-data)),
      authorization-progress: (get received-authorizations override-data),
      required-authorizations: (get required-authorizations override-data),
      time-remaining: (- (get expires-at override-data) stacks-block-height),
      status: (get status override-data)
    }
    {
      is-authorized: false,
      authorization-progress: u0,
      required-authorizations: u0,
      time-remaining: u0,
      status: "NOT_FOUND"
    }
  )
)

(define-read-only (get-active-emergencies-for-provider (provider-id principal))
  ;; Simplified implementation - would need proper indexing in production
  {
    total-active: u0,
    pending-authorization: u0,
    requires-validation: u0
  }
)
