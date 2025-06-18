(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PERCENTAGE (err u101))
(define-constant ERR_TRACK_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_NO_COLLABORATORS (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_WITHDRAWAL_FAILED (err u107))

(define-map tracks
  { track-id: uint }
  {
    title: (string-ascii 100),
    creator: principal,
    total-earnings: uint,
    is-active: bool
  }
)

(define-map collaborators
  { track-id: uint, collaborator: principal }
  {
    percentage: uint,
    earnings: uint,
    withdrawn: uint
  }
)

(define-map track-collaborator-count
  { track-id: uint }
  { count: uint }
)

(define-data-var next-track-id uint u1)

(define-public (create-track (title (string-ascii 100)) (collaborator-list (list 10 { collaborator: principal, percentage: uint })))
  (let
    (
      (track-id (var-get next-track-id))
      (total-percentage (fold + (map get-percentage collaborator-list) u0))
    )
    (asserts! (is-eq total-percentage u100) ERR_INVALID_PERCENTAGE)
    (asserts! (> (len collaborator-list) u0) ERR_NO_COLLABORATORS)
    (unwrap! (add-track track-id title) ERR_ALREADY_EXISTS)
    (unwrap! (add-collaborators track-id collaborator-list) ERR_INVALID_PERCENTAGE)
    (var-set next-track-id (+ track-id u1))
    (ok track-id)
  )
)

(define-private (get-percentage (collab { collaborator: principal, percentage: uint }))
  (get percentage collab)
)

(define-private (add-track (track-id uint) (title (string-ascii 100)))
  (begin
    (map-set tracks
      { track-id: track-id }
      {
        title: title,
        creator: tx-sender,
        total-earnings: u0,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-private (add-collaborators (track-id uint) (collaborator-list (list 10 { collaborator: principal, percentage: uint })))
  (begin
    (map-set track-collaborator-count
      { track-id: track-id }
      { count: (len collaborator-list) }
    )
    (ok (fold add-single-collaborator collaborator-list { track-id: track-id, success: true }))
  )
)

(define-private (add-single-collaborator 
  (collab { collaborator: principal, percentage: uint })
  (context { track-id: uint, success: bool })
)
  (begin
    (map-set collaborators
      { track-id: (get track-id context), collaborator: (get collaborator collab) }
      {
        percentage: (get percentage collab),
        earnings: u0,
        withdrawn: u0
      }
    )
    context
  )
)

(define-public (add-royalty (track-id uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
      (amount (stx-get-balance tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active track) ERR_TRACK_NOT_FOUND)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (distribute-royalty track-id amount))
    (map-set tracks
      { track-id: track-id }
      (merge track { total-earnings: (+ (get total-earnings track) amount) })
    )
    (ok amount)
  )
)

(define-public (add-royalty-amount (track-id uint) (amount uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get is-active track) ERR_TRACK_NOT_FOUND)
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (distribute-royalty track-id amount))
    (map-set tracks
      { track-id: track-id }
      (merge track { total-earnings: (+ (get total-earnings track) amount) })
    )
    (ok amount)
  )
)

(define-private (distribute-royalty (track-id uint) (amount uint))
  (let
    (
      (collaborator-count (default-to { count: u0 } (map-get? track-collaborator-count { track-id: track-id })))
    )
    (asserts! (> (get count collaborator-count) u0) ERR_NO_COLLABORATORS)
    (ok (distribute-to-collaborators track-id amount))
  )
)

(define-private (distribute-to-collaborators (track-id uint) (amount uint))
  (begin
    (map-set distribution-context { track-id: track-id, amount: amount, processed: u0 } { success: true })
    true
  )
)

(define-map distribution-context
  { track-id: uint, amount: uint, processed: uint }
  { success: bool }
)

(define-public (withdraw-earnings (track-id uint))
  (let
    (
      (collaborator-data (unwrap! (map-get? collaborators { track-id: track-id, collaborator: tx-sender }) ERR_NOT_AUTHORIZED))
      (available-earnings (- (get earnings collaborator-data) (get withdrawn collaborator-data)))
    )
    (asserts! (> available-earnings u0) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? available-earnings tx-sender tx-sender)))
    (map-set collaborators
      { track-id: track-id, collaborator: tx-sender }
      (merge collaborator-data { withdrawn: (+ (get withdrawn collaborator-data) available-earnings) })
    )
    (ok available-earnings)
  )
)

(define-public (update-collaborator-earnings (track-id uint) (collaborator principal) (additional-earnings uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
      (collaborator-data (unwrap! (map-get? collaborators { track-id: track-id, collaborator: collaborator }) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (map-set collaborators
      { track-id: track-id, collaborator: collaborator }
      (merge collaborator-data { earnings: (+ (get earnings collaborator-data) additional-earnings) })
    )
    (ok true)
  )
)

(define-read-only (get-track (track-id uint))
  (map-get? tracks { track-id: track-id })
)

(define-read-only (get-collaborator-info (track-id uint) (collaborator principal))
  (map-get? collaborators { track-id: track-id, collaborator: collaborator })
)

(define-read-only (get-available-earnings (track-id uint) (collaborator principal))
  (match (map-get? collaborators { track-id: track-id, collaborator: collaborator })
    collab-data (ok (- (get earnings collab-data) (get withdrawn collab-data)))
    ERR_NOT_AUTHORIZED
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-next-track-id)
  (var-get next-track-id)
)

(define-public (deactivate-track (track-id uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (map-set tracks
      { track-id: track-id }
      (merge track { is-active: false })
    )
    (ok true)
  )
)

(define-public (calculate-and-distribute (track-id uint) (amount uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (try! (process-distribution track-id amount))
    (ok true)
  )
)

(define-private (process-distribution (track-id uint) (amount uint))
  (let
    (
      (result (update-all-collaborator-earnings track-id amount))
    )
    (if (is-ok result)
      result
      (err u999) 
    )
  )
)

(define-private (update-all-collaborator-earnings (track-id uint) (total-amount uint))
  (ok true)
)

(define-public (manual-distribute (track-id uint) (collaborator principal))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
      (collaborator-data (unwrap! (map-get? collaborators { track-id: track-id, collaborator: collaborator }) ERR_NOT_AUTHORIZED))
      (contract-balance (stx-get-balance (as-contract tx-sender)))
      (share-amount (/ (* contract-balance (get percentage collaborator-data)) u100))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (asserts! (> share-amount u0) ERR_INVALID_AMOUNT)
    (map-set collaborators
      { track-id: track-id, collaborator: collaborator }
      (merge collaborator-data { earnings: (+ (get earnings collaborator-data) share-amount) })
    )
    (ok share-amount)
  )
)

(define-public (distribute-royalty-to-collaborator (track-id uint) (collaborator principal) (amount uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
      (collaborator-data (unwrap! (map-get? collaborators { track-id: track-id, collaborator: collaborator }) ERR_NOT_AUTHORIZED))
      (percentage (get percentage collaborator-data))
      (earnings-share (/ (* amount percentage) u100))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (map-set collaborators
      { track-id: track-id, collaborator: collaborator }
      (merge collaborator-data { earnings: (+ (get earnings collaborator-data) earnings-share) })
    )
    (ok earnings-share)
  )
)

(define-public (batch-distribute (track-id uint) (amount uint) (collaborator-list (list 10 principal)))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (ok (fold distribute-to-single-collaborator collaborator-list { track-id: track-id, amount: amount, success: true }))
  )
)

(define-private (distribute-to-single-collaborator 
  (collaborator principal)
  (context { track-id: uint, amount: uint, success: bool })
)
  (let
    (
      (collaborator-data (default-to { percentage: u0, earnings: u0, withdrawn: u0 } 
                         (map-get? collaborators { track-id: (get track-id context), collaborator: collaborator })))
      (percentage (get percentage collaborator-data))
      (earnings-share (/ (* (get amount context) percentage) u100))
    )
    (if (> percentage u0)
      (begin
        (map-set collaborators
          { track-id: (get track-id context), collaborator: collaborator }
          (merge collaborator-data { earnings: (+ (get earnings collaborator-data) earnings-share) })
        )
        context
      )
      context
    )
  )
)

(define-read-only (get-track-total-percentage (track-id uint))
  (let
    (
      (count-data (default-to { count: u0 } (map-get? track-collaborator-count { track-id: track-id })))
    )
    (ok (get count count-data))
  )
)

(define-public (emergency-withdraw (track-id uint) (amount uint))
  (let
    (
      (track (unwrap! (map-get? tracks { track-id: track-id }) ERR_TRACK_NOT_FOUND))
      (contract-balance (stx-get-balance (as-contract tx-sender)))
    )
    (asserts! (is-eq tx-sender (get creator track)) ERR_NOT_AUTHORIZED)
    (asserts! (<= amount contract-balance) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender (get creator track))))
    (ok amount)
  )
)
