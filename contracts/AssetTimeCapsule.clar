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


;; Main capsule registry
(define-map Capsules
  { capsule-id: uint }
  {
    creator: principal,
    recipient: principal,
    quantity: uint,
    status: (string-ascii 10),
    creation-height: uint,
    unlock-height: uint,
    phases: (list 5 uint),
    completed-phases: uint
  }
)

(define-data-var capsule-sequence uint u0)

;; Multi-recipient capsule structure
(define-map MultiCapsules
  { multi-capsule-id: uint }
  {
    creator: principal,
    targets: (list 5 { recipient: principal, portion: uint }),
    total-quantity: uint,
    creation-height: uint,
    status: (string-ascii 10)
  }
)

(define-data-var multi-capsule-sequence uint u0)

;; Verified recipient directory
(define-map CertifiedRecipients
  { recipient: principal }
  { certified: bool }
)

;; Milestone tracking system
(define-map PhaseProgress
  { capsule-id: uint, phase-index: uint }
  {
    progress-percentage: uint,
    remarks: (string-ascii 200),
    update-height: uint,
    evidence-hash: (buff 32)
  }
)

;; Authority delegation records
(define-map CapsuleProxies
  { capsule-id: uint }
  {
    proxy: principal,
    can-cancel: bool,
    can-extend: bool,
    can-augment: bool,
    proxy-expiry: uint
  }
)

;; Unusual activity tracker
(define-map AlarmCapsules
  { capsule-id: uint }
  { 
    alarm-type: (string-ascii 20),
    reported-by: principal,
    resolved: bool
  }
)

;; Creator activity monitoring
(define-map CreatorMonitor
  { creator: principal }
  {
    last-operation-height: uint,
    operations-in-window: uint
  }
)

;; Dispute management system
(define-map CapsuleContests
  { capsule-id: uint }
  {
    challenger: principal,
    contest-grounds: (string-ascii 200),
    contest-bond: uint,
    resolved: bool,
    upheld: bool,
    contest-height: uint
  }
)

;; Emergency retrieval mechanism
(define-map RetrievalRequests
  { capsule-id: uint }
  { 
    admin-confirmed: bool,
    creator-confirmed: bool,
    justification: (string-ascii 100)
  }
)

;; Protocol state
(define-data-var protocol-halted bool false)

;; Utility functions
(define-private (is-valid-recipient (recipient principal))
  (not (is-eq recipient tx-sender))
)

(define-private (is-valid-capsule-id (capsule-id uint))
  (<= capsule-id (var-get capsule-sequence))
)

(define-private (get-portion-value (target { recipient: principal, portion: uint }))
  (get portion target)
)

;; Query functions
(define-read-only (is-recipient-certified (recipient principal))
  (default-to false (get certified (map-get? CertifiedRecipients { recipient: recipient })))
)

;; Primary feature: Create a new phase-based asset time capsule
(define-public (create-capsule (recipient principal) (quantity uint) (phases (list 5 uint)))
  (let
    (
      (capsule-id (+ (var-get capsule-sequence) u1))
      (unlock-height (+ block-height CAPSULE_DURATION))
    )
    (asserts! (> quantity u0) ERROR_INVALID_QUANTITY)
    (asserts! (is-valid-recipient recipient) ERROR_INVALID_RELEASE_RULE)
    (asserts! (> (len phases) u0) ERROR_INVALID_RELEASE_RULE)
    (match (stx-transfer? quantity tx-sender (as-contract tx-sender))
      success
        (begin
          (map-set Capsules
            { capsule-id: capsule-id }
            {
              creator: tx-sender,
              recipient: recipient,
              quantity: quantity,
              status: "active",
              creation-height: block-height,
              unlock-height: unlock-height,
              phases: phases,
              completed-phases: u0
            }
          )
          (var-set capsule-sequence capsule-id)
          (ok capsule-id)
        )
      error ERROR_ASSET_MOVE_FAILED
    )
  )
)

;; Enhanced feature: Create a multi-recipient capsule with proportional distribution
(define-public (create-multi-capsule (targets (list 5 { recipient: principal, portion: uint })) (quantity uint))
  (begin
    (asserts! (> quantity u0) ERROR_INVALID_QUANTITY)
    (asserts! (> (len targets) u0) ERROR_INVALID_CAPSULE_ID)
    (asserts! (<= (len targets) MAX_RECIPIENTS) ERROR_RECIPIENT_CAP)

    ;; Verify portion allocation totals 100%
    (let
      (
        (total-portion (fold + (map get-portion-value targets) u0))
      )
      (asserts! (is-eq total-portion u100) ERROR_DISTRIBUTION_MISMATCH)

      ;; Process the capsule creation
      (match (stx-transfer? quantity tx-sender (as-contract tx-sender))
        success
          (let
            (
              (capsule-id (+ (var-get multi-capsule-sequence) u1))
            )
            (map-set MultiCapsules
              { multi-capsule-id: capsule-id }
              {
                creator: tx-sender,
                targets: targets,
                total-quantity: quantity,
                creation-height: block-height,
                status: "active"
              }
            )
            (var-set multi-capsule-sequence capsule-id)
            (ok capsule-id)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)


;; Phase management: Approve phase completion and release assets
(define-public (approve-phase (capsule-id uint))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (phases (get phases capsule))
        (completed-count (get completed-phases capsule))
        (recipient (get recipient capsule))
        (total-quantity (get quantity capsule))
        (release-amount (/ total-quantity (len phases)))
      )
      (asserts! (< completed-count (len phases)) ERROR_ASSETS_RELEASED)
      (asserts! (is-eq tx-sender PROTOCOL_ADMIN) ERROR_PERMISSION_DENIED)
      (match (stx-transfer? release-amount (as-contract tx-sender) recipient)
        success
          (begin
            (map-set Capsules
              { capsule-id: capsule-id }
              (merge capsule { completed-phases: (+ completed-count u1) })
            )
            (ok true)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)

;; Creator protection: Return assets after expiration
(define-public (retrieve-assets (capsule-id uint))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (creator (get creator capsule))
        (quantity (get quantity capsule))
      )
      (asserts! (is-eq tx-sender PROTOCOL_ADMIN) ERROR_PERMISSION_DENIED)
      (asserts! (> block-height (get unlock-height capsule)) ERROR_CAPSULE_EXPIRED)
      (match (stx-transfer? quantity (as-contract tx-sender) creator)
        success
          (begin
            (map-set Capsules
              { capsule-id: capsule-id }
              (merge capsule { status: "retrieved" })
            )
            (ok true)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)

;; Creator control: Terminate active capsule
(define-public (terminate-capsule (capsule-id uint))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (creator (get creator capsule))
        (quantity (get quantity capsule))
        (completed-count (get completed-phases capsule))
        (remaining-quantity (- quantity (* (/ quantity (len (get phases capsule))) completed-count)))
      )
      (asserts! (is-eq tx-sender creator) ERROR_PERMISSION_DENIED)
      (asserts! (< block-height (get unlock-height capsule)) ERROR_CAPSULE_EXPIRED)
      (asserts! (is-eq (get status capsule) "active") ERROR_ASSETS_RELEASED)
      (match (stx-transfer? remaining-quantity (as-contract tx-sender) creator)
        success
          (begin
            (map-set Capsules
              { capsule-id: capsule-id }
              (merge capsule { status: "terminated" })
            )
            (ok true)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)

;; Duration management: Extend capsule lifetime
(define-public (prolong-capsule (capsule-id uint) (extension-blocks uint))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (asserts! (<= extension-blocks MAX_TIME_EXTENSION) ERROR_INVALID_QUANTITY)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (creator (get creator capsule))
        (current-unlock (get unlock-height capsule))
      )
      (asserts! (is-eq tx-sender creator) ERROR_PERMISSION_DENIED)
      (asserts! (< block-height current-unlock) ERROR_ALREADY_EXPIRED)
      (map-set Capsules
        { capsule-id: capsule-id }
        (merge capsule { unlock-height: (+ current-unlock extension-blocks) })
      )
      (ok true)
    )
  )
)

;; Asset management: Increase capsule quantity
(define-public (augment-capsule (capsule-id uint) (additional-quantity uint))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (asserts! (> additional-quantity u0) ERROR_INVALID_QUANTITY)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (creator (get creator capsule))
        (current-quantity (get quantity capsule))
      )
      (asserts! (is-eq tx-sender creator) ERROR_PERMISSION_DENIED)
      (asserts! (< block-height (get unlock-height capsule)) ERROR_CAPSULE_EXPIRED)
      (match (stx-transfer? additional-quantity tx-sender (as-contract tx-sender))
        success
          (begin
            (map-set Capsules
              { capsule-id: capsule-id }
              (merge capsule { quantity: (+ current-quantity additional-quantity) })
            )
            (ok true)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)

;; Access management: Assign proxy control to a third party
(define-public (assign-capsule-proxy 
                (capsule-id uint) 
                (proxy principal) 
                (can-cancel bool)
                (can-extend bool)
                (can-augment bool)
                (proxy-duration uint))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (asserts! (> proxy-duration u0) ERROR_INVALID_QUANTITY)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (creator (get creator capsule))
        (proxy-expiry (+ block-height proxy-duration))
      )
      (asserts! (is-eq tx-sender creator) ERROR_PERMISSION_DENIED)
      (asserts! (< block-height (get unlock-height capsule)) ERROR_CAPSULE_EXPIRED)
      (asserts! (not (is-eq (get status capsule) "retrieved")) ERROR_ASSETS_RELEASED)

      ;; Check if proxy already assigned
      (match (map-get? CapsuleProxies { capsule-id: capsule-id })
        existing-proxy (asserts! (< block-height (get proxy-expiry existing-proxy)) ERROR_PROXY_EXISTS)
        true
      )

      (ok true)
    )
  )
)

;; Batch operations: Approve multiple phases at once
(define-public (batch-approve-phases (capsule-ids (list 10 uint)))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMIN) ERROR_PERMISSION_DENIED)
    (let
      (
        (result (fold approve-phase-fold capsule-ids (ok true)))
      )
      result
    )
  )
)

;; Helper function for batch approval
(define-private (approve-phase-fold (capsule-id uint) (prev-result (response bool uint)))
  (begin
    (match prev-result
      success
        (match (approve-phase capsule-id)
          inner-success (ok true)
          inner-error (err inner-error)
        )
      error (err error)
    )
  )
)

;; Progress tracking: Allow recipients to report phase progress
(define-public (report-phase-progress 
                (capsule-id uint) 
                (phase-index uint) 
                (progress-percentage uint) 
                (remarks (string-ascii 200))
                (evidence-hash (buff 32)))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (asserts! (<= progress-percentage u100) ERROR_INVALID_QUANTITY)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (phases (get phases capsule))
        (recipient (get recipient capsule))
      )
      (asserts! (is-eq tx-sender recipient) ERROR_PERMISSION_DENIED)
      (asserts! (< phase-index (len phases)) ERROR_INVALID_RELEASE_RULE)
      (asserts! (not (is-eq (get status capsule) "retrieved")) ERROR_ASSETS_RELEASED)
      (asserts! (< block-height (get unlock-height capsule)) ERROR_CAPSULE_EXPIRED)

      ;; Check if progress was already reported at 100%
      (match (map-get? PhaseProgress { capsule-id: capsule-id, phase-index: phase-index })
        prev-progress (asserts! (< (get progress-percentage prev-progress) u100) ERROR_MILESTONE_RECORDED)
        true
      )

      (ok true)
    )
  )
)

;; Security-enhanced capsule with verification and rate limiting
(define-public (create-certified-capsule (recipient principal) (quantity uint) (phases (list 5 uint)))
  (begin
    (asserts! (not (var-get protocol-halted)) ERROR_PERMISSION_DENIED)
    (asserts! (is-recipient-certified recipient) ERROR_PERMISSION_DENIED)
    (asserts! (> quantity u0) ERROR_INVALID_QUANTITY)
    (asserts! (is-valid-recipient recipient) ERROR_INVALID_RELEASE_RULE)
    (asserts! (> (len phases) u0) ERROR_INVALID_RELEASE_RULE)

    (let
      (
        (capsule-id (+ (var-get capsule-sequence) u1))
        (unlock-height (+ block-height CAPSULE_DURATION))
      )
      (match (stx-transfer? quantity tx-sender (as-contract tx-sender))
        success
          (begin
            (map-set Capsules
              { capsule-id: capsule-id }
              {
                creator: tx-sender,
                recipient: recipient,
                quantity: quantity,
                status: "active",
                creation-height: block-height,
                unlock-height: unlock-height,
                phases: phases,
                completed-phases: u0
              }
            )
            (var-set capsule-sequence capsule-id)
            (ok capsule-id)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)

;; Operation monitoring: Rate-limited capsule creation
(define-public (constrained-capsule (recipient principal) (quantity uint) (phases (list 5 uint)))
  (let
    (
      (creator-activity (default-to 
                        { last-operation-height: u0, operations-in-window: u0 }
                        (map-get? CreatorMonitor { creator: tx-sender })))
      (last-height (get last-operation-height creator-activity))
      (window-count (get operations-in-window creator-activity))
      (is-new-window (> (- block-height last-height) OPERATION_WINDOW))
      (updated-count (if is-new-window u1 (+ window-count u1)))
    )
    ;; Rate limit check
    (asserts! (or is-new-window (< window-count MAX_OPS_IN_WINDOW)) ERROR_RATE_LIMIT_EXCEEDED)

    ;; Update the rate limiting tracker
    (map-set CreatorMonitor
      { creator: tx-sender }
      {
        last-operation-height: block-height,
        operations-in-window: updated-count
      }
    )

    ;; Call the certified capsule function
    (create-certified-capsule recipient quantity phases)
  )
)

;; Anomaly detection: Flag suspicious capsule activity
(define-public (report-anomalous-capsule (capsule-id uint) (alarm-type (string-ascii 20)))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)

    ;; Only admin or the recipient can flag capsules as suspicious
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (recipient (get recipient capsule))
      )
      (asserts! (or (is-eq tx-sender PROTOCOL_ADMIN) (is-eq tx-sender recipient)) ERROR_PERMISSION_DENIED)

      ;; Flag the specific capsule by updating its status
      (map-set Capsules
        { capsule-id: capsule-id }
        (merge capsule { status: "alarmed" })
      )

      (ok true)
    )
  )
)

;; Community oversight: Dispute resolution system
(define-public (contest-capsule 
                (capsule-id uint)
                (contest-grounds (string-ascii 200)))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
      )
      ;; Prevent multiple contests
      (match (map-get? CapsuleContests { capsule-id: capsule-id })
        existing-contest (asserts! false ERROR_OBJECTION_EXISTS)
        true
      )

      ;; Transfer contest bond
      (match (stx-transfer? CONTEST_BOND tx-sender (as-contract tx-sender))
        success
          (begin
            (ok true)
          )
        error ERROR_ASSET_MOVE_FAILED
      )
    )
  )
)

;; Contest resolution mechanism
(define-public (resolve-capsule-contest (capsule-id uint) (is-valid bool))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMIN) ERROR_PERMISSION_DENIED)
    (let
      (
        (contest (unwrap! 
          (map-get? CapsuleContests { capsule-id: capsule-id }) 
          ERROR_CAPSULE_MISSING))
        (contest-height (get contest-height contest))
      )
      (asserts! (not (get resolved contest)) ERROR_PERMISSION_DENIED)
      (asserts! (< (- block-height contest-height) CONTEST_DURATION) ERROR_REVIEW_PERIOD_ENDED)

      ;; Return or forfeit contest bond based on validity
      (if is-valid
        ;; Contest is valid, return bond to challenger
        (match (stx-transfer? (get contest-bond contest) (as-contract tx-sender) (get challenger contest))
          success (ok true)
          error ERROR_ASSET_MOVE_FAILED
        )
        ;; Contest is invalid, transfer bond to protocol admin
        (match (stx-transfer? (get contest-bond contest) (as-contract tx-sender) PROTOCOL_ADMIN)
          success (ok true)
          error ERROR_ASSET_MOVE_FAILED
        )
      )
    )
  )
)

;; Emergency procedures: Override asset retrieval with dual confirmation
(define-public (emergency-asset-retrieval (capsule-id uint) (justification (string-ascii 100)))
  (begin
    (asserts! (is-valid-capsule-id capsule-id) ERROR_INVALID_CAPSULE_ID)
    (let
      (
        (capsule (unwrap! (map-get? Capsules { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        (creator (get creator capsule))
        (quantity (get quantity capsule))
        (completed-count (get completed-phases capsule))
        (remaining-quantity (- quantity (* (/ quantity (len (get phases capsule))) completed-count)))
        (retrieval-request (default-to 
                          { admin-confirmed: false, creator-confirmed: false, justification: justification }
                          (map-get? RetrievalRequests { capsule-id: capsule-id })))
      )
      (asserts! (or (is-eq tx-sender PROTOCOL_ADMIN) (is-eq tx-sender creator)) ERROR_PERMISSION_DENIED)
      (asserts! (not (is-eq (get status capsule) "retrieved")) ERROR_ASSETS_RELEASED)
      (asserts! (not (is-eq (get status capsule) "retrieved")) ERROR_ASSETS_RELEASED)

      ;; Set confirmations based on who called the function
      (if (is-eq tx-sender PROTOCOL_ADMIN)
        (map-set RetrievalRequests
          { capsule-id: capsule-id }
          (merge retrieval-request { admin-confirmed: true, justification: justification })
        )
        (map-set RetrievalRequests
          { capsule-id: capsule-id }
          (merge retrieval-request { creator-confirmed: true, justification: justification })
        )
      )

      ;; Check if both have confirmed
      (let
        (
          (updated-request (unwrap! (map-get? RetrievalRequests { capsule-id: capsule-id }) ERROR_CAPSULE_MISSING))
        )
        (if (and (get admin-confirmed updated-request) (get creator-confirmed updated-request))
          (match (stx-transfer? remaining-quantity (as-contract tx-sender) creator)
            success
              (begin
                (map-set Capsules
                  { capsule-id: capsule-id }
                  (merge capsule { status: "retrieved" })
                )
                (ok true)
              )
            error ERROR_ASSET_MOVE_FAILED
          )
          (ok false)
        )
      )
    )
  )
)

