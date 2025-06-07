(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PATIENT_NOT_FOUND (err u101))
(define-constant ERR_CONSENT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_EXPIRY (err u103))
(define-constant ERR_CONSENT_EXPIRED (err u104))
(define-constant ERR_CONSENT_REVOKED (err u105))
(define-constant ERR_PROVIDER_NOT_AUTHORIZED (err u106))
(define-constant ERR_ALREADY_EXISTS (err u107))

(define-map patients
  { patient-id: principal }
  {
    name: (string-ascii 100),
    date-of-birth: (string-ascii 10),
    emergency-contact: (string-ascii 100),
    created-at: uint,
    is-active: bool
  }
)

(define-map healthcare-providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialty: (string-ascii 100),
    is-verified: bool,
    created-at: uint
  }
)

(define-map consent-records
  { consent-id: uint }
  {
    patient-id: principal,
    provider-id: principal,
    treatment-type: (string-ascii 200),
    description: (string-ascii 500),
    consent-given: bool,
    expiry-date: uint,
    created-at: uint,
    updated-at: uint,
    is-revoked: bool,
    revocation-reason: (optional (string-ascii 200))
  }
)

(define-map patient-consents
  { patient-id: principal, provider-id: principal, treatment-type: (string-ascii 200) }
  { consent-id: uint }
)

(define-data-var next-consent-id uint u1)

(define-public (register-patient (name (string-ascii 100)) (date-of-birth (string-ascii 10)) (emergency-contact (string-ascii 100)))
  (let ((patient-id tx-sender))
    (if (is-some (map-get? patients { patient-id: patient-id }))
      ERR_ALREADY_EXISTS
      (begin
        (map-set patients
          { patient-id: patient-id }
          {
            name: name,
            date-of-birth: date-of-birth,
            emergency-contact: emergency-contact,
            created-at: stacks-block-height,
            is-active: true
          }
        )
        (ok patient-id)
      )
    )
  )
)

(define-public (register-provider (name (string-ascii 100)) (license-number (string-ascii 50)) (specialty (string-ascii 100)))
  (let ((provider-id tx-sender))
    (if (is-some (map-get? healthcare-providers { provider-id: provider-id }))
      ERR_ALREADY_EXISTS
      (begin
        (map-set healthcare-providers
          { provider-id: provider-id }
          {
            name: name,
            license-number: license-number,
            specialty: specialty,
            is-verified: false,
            created-at: stacks-block-height
          }
        )
        (ok provider-id)
      )
    )
  )
)

(define-public (verify-provider (provider-id principal))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (match (map-get? healthcare-providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set healthcare-providers
          { provider-id: provider-id }
          (merge provider-data { is-verified: true })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_AUTHORIZED
    )
    ERR_UNAUTHORIZED
  )
)

(define-public (give-consent (provider-id principal) (treatment-type (string-ascii 200)) (description (string-ascii 500)) (expiry-date uint))
  (let (
    (patient-id tx-sender)
    (consent-id (var-get next-consent-id))
  )
    (if (and
      (is-some (map-get? patients { patient-id: patient-id }))
      (is-some (map-get? healthcare-providers { provider-id: provider-id }))
      (> expiry-date stacks-block-height)
    )
      (begin
        (map-set consent-records
          { consent-id: consent-id }
          {
            patient-id: patient-id,
            provider-id: provider-id,
            treatment-type: treatment-type,
            description: description,
            consent-given: true,
            expiry-date: expiry-date,
            created-at: stacks-block-height,
            updated-at: stacks-block-height,
            is-revoked: false,
            revocation-reason: none
          }
        )
        (map-set patient-consents
          { patient-id: patient-id, provider-id: provider-id, treatment-type: treatment-type }
          { consent-id: consent-id }
        )
        (var-set next-consent-id (+ consent-id u1))
        (ok consent-id)
      )
      ERR_INVALID_EXPIRY
    )
  )
)

(define-public (revoke-consent (consent-id uint) (reason (string-ascii 200)))
  (match (map-get? consent-records { consent-id: consent-id })
    consent-data
    (if (is-eq tx-sender (get patient-id consent-data))
      (begin
        (map-set consent-records
          { consent-id: consent-id }
          (merge consent-data {
            is-revoked: true,
            revocation-reason: (some reason),
            updated-at: stacks-block-height
          })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_CONSENT_NOT_FOUND
  )
)

(define-public (update-consent (consent-id uint) (new-expiry-date uint) (new-description (string-ascii 500)))
  (match (map-get? consent-records { consent-id: consent-id })
    consent-data
    (if (and
      (is-eq tx-sender (get patient-id consent-data))
      (> new-expiry-date stacks-block-height)
      (not (get is-revoked consent-data))
    )
      (begin
        (map-set consent-records
          { consent-id: consent-id }
          (merge consent-data {
            description: new-description,
            expiry-date: new-expiry-date,
            updated-at: stacks-block-height
          })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_CONSENT_NOT_FOUND
  )
)

(define-read-only (get-patient (patient-id principal))
  (map-get? patients { patient-id: patient-id })
)

(define-read-only (get-provider (provider-id principal))
  (map-get? healthcare-providers { provider-id: provider-id })
)

(define-read-only (get-consent (consent-id uint))
  (map-get? consent-records { consent-id: consent-id })
)

(define-read-only (check-consent-validity (patient-id principal) (provider-id principal) (treatment-type (string-ascii 200)))
  (match (map-get? patient-consents { patient-id: patient-id, provider-id: provider-id, treatment-type: treatment-type })
    consent-ref
    (match (map-get? consent-records { consent-id: (get consent-id consent-ref) })
      consent-data
      (if (and
        (get consent-given consent-data)
        (not (get is-revoked consent-data))
        (> (get expiry-date consent-data) stacks-block-height)
      )
        (ok true)
        (ok false)
      )
      (ok false)
    )
    (ok false)
  )
)

(define-read-only (get-consent-by-treatment (patient-id principal) (provider-id principal) (treatment-type (string-ascii 200)))
  (match (map-get? patient-consents { patient-id: patient-id, provider-id: provider-id, treatment-type: treatment-type })
    consent-ref
    (map-get? consent-records { consent-id: (get consent-id consent-ref) })
    none
  )
)

(define-read-only (is-provider-verified (provider-id principal))
  (match (map-get? healthcare-providers { provider-id: provider-id })
    provider-data
    (get is-verified provider-data)
    false
  )
)

(define-read-only (get-next-consent-id)
  (var-get next-consent-id)
)