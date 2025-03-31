;; AssetTimeCapsule: A blockchain-based time capsule system for assets with conditional release. It enables time-bound asset transfers with phase-based conditional releases and comprehensive protection mechanisms.

;; Base administration parameters
(define-constant PROTOCOL_ADMIN tx-sender)
(define-constant ERROR_PERMISSION_DENIED (err u200))
(define-constant ERROR_CAPSULE_MISSING (err u201))
(define-constant ERROR_ASSETS_RELEASED (err u202))
(define-constant ERROR_ASSET_MOVE_FAILED (err u203))
(define-constant ERROR_INVALID_CAPSULE_ID (err u204))
(define-constant ERROR_INVALID_QUANTITY (err u205))
(define-constant ERROR_INVALID_RELEASE_RULE (err u206))
(define-constant ERROR_CAPSULE_EXPIRED (err u207))
(define-constant CAPSULE_DURATION u1008)

;; Supplementary error indicators
(define-constant ERROR_ALREADY_EXPIRED (err u208))
(define-constant ERROR_OVERRIDE_MISSING (err u209))
(define-constant ERROR_MILESTONE_RECORDED (err u210))
(define-constant ERROR_PROXY_EXISTS (err u211))
(define-constant ERROR_BULK_OPERATION_FAILED (err u212))
(define-constant ERROR_RATE_LIMIT_EXCEEDED (err u213))
(define-constant ERROR_ANOMALOUS_PATTERN (err u215))
(define-constant ERROR_OBJECTION_EXISTS (err u236))
(define-constant ERROR_REVIEW_PERIOD_ENDED (err u237))

;; Protocol guardrails
(define-constant PROTECTION_DELAY u720) 
(define-constant ERROR_PROTECTION_ACTIVE (err u222))
(define-constant ERROR_PROTECTION_COOLING (err u223))
(define-constant MAX_RECIPIENTS u5)
(define-constant ERROR_RECIPIENT_CAP (err u224))
(define-constant ERROR_DISTRIBUTION_MISMATCH (err u225))
(define-constant MAX_TIME_EXTENSION u1008) 
(define-constant OPERATION_WINDOW u144) 
(define-constant MAX_OPS_IN_WINDOW u5)
(define-constant HIGH_VALUE_THRESHOLD u1000000000) 
(define-constant RAPID_TRANSFER_THRESHOLD u3) 
(define-constant CONTEST_DURATION u1008) 
(define-constant CONTEST_BOND u1000000) 

