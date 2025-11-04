(define-constant ERR_TRACK_NOT_FOUND (err u400))
(define-constant ERR_SUBSCRIPTION_NOT_FOUND (err u401))
(define-constant ERR_ALREADY_SUBSCRIBED (err u402))
(define-constant ERR_NOT_SUBSCRIBED (err u403))
(define-constant ERR_PAYMENT_TOO_EARLY (err u404))
(define-constant ERR_INSUFFICIENT_FUNDS (err u405))
(define-constant ERR_NOT_AUTHORIZED (err u406))

(define-constant BILLING_CYCLE_BLOCKS u4320)

(define-map subscription-tiers
  { track-id: uint, tier-level: uint }
  { price-per-cycle: uint, is-active: bool }
)

(define-map active-subscriptions
  { track-id: uint, subscriber: principal }
  { 
    tier-level: uint,
    start-block: uint,
    last-payment-block: uint,
    next-payment-block: uint,
    total-paid: uint,
    is-active: bool
  }
)

(define-map track-subscriber-count
  { track-id: uint }
  { count: uint, total-revenue: uint }
)

(define-data-var total-subscriptions uint u0)

(define-public (create-subscription-tier (track-id uint) (tier-level uint) (price uint))
  (let
    (
      (track-info (unwrap! (contract-call? .Music-Collaboration-Smart-Contract get-track track-id) ERR_TRACK_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator track-info)) ERR_NOT_AUTHORIZED)
    (map-set subscription-tiers
      { track-id: track-id, tier-level: tier-level }
      { price-per-cycle: price, is-active: true }
    )
    (ok true)
  )
)

(define-public (subscribe-to-track (track-id uint) (tier-level uint))
  (let
    (
      (tier-data (unwrap! (map-get? subscription-tiers { track-id: track-id, tier-level: tier-level }) ERR_TRACK_NOT_FOUND))
      (existing-sub (map-get? active-subscriptions { track-id: track-id, subscriber: tx-sender }))
      (price (get price-per-cycle tier-data))
    )
    (asserts! (is-none existing-sub) ERR_ALREADY_SUBSCRIBED)
    (asserts! (get is-active tier-data) ERR_TRACK_NOT_FOUND)
    (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
    (try! (contract-call? .Music-Collaboration-Smart-Contract add-royalty-amount track-id price))
    (begin
      (map-set active-subscriptions
        { track-id: track-id, subscriber: tx-sender }
        {
          tier-level: tier-level,
          start-block: stacks-block-height,
          last-payment-block: stacks-block-height,
          next-payment-block: (+ stacks-block-height BILLING_CYCLE_BLOCKS),
          total-paid: price,
          is-active: true
        }
      )
      (update-track-stats track-id price true)
      (var-set total-subscriptions (+ (var-get total-subscriptions) u1))
      (ok true)
    )
  )
)

(define-public (collect-subscription-payment (track-id uint) (subscriber principal))
  (let
    (
      (sub-data (unwrap! (map-get? active-subscriptions { track-id: track-id, subscriber: subscriber }) ERR_SUBSCRIPTION_NOT_FOUND))
      (tier-data (unwrap! (map-get? subscription-tiers { track-id: track-id, tier-level: (get tier-level sub-data) }) ERR_TRACK_NOT_FOUND))
      (price (get price-per-cycle tier-data))
    )
    (asserts! (get is-active sub-data) ERR_NOT_SUBSCRIBED)
    (asserts! (>= stacks-block-height (get next-payment-block sub-data)) ERR_PAYMENT_TOO_EARLY)
    (asserts! (>= (stx-get-balance subscriber) price) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? price subscriber tx-sender)))
    (try! (contract-call? .Music-Collaboration-Smart-Contract add-royalty-amount track-id price))
    (begin
      (map-set active-subscriptions
        { track-id: track-id, subscriber: subscriber }
        (merge sub-data {
          last-payment-block: stacks-block-height,
          next-payment-block: (+ stacks-block-height BILLING_CYCLE_BLOCKS),
          total-paid: (+ (get total-paid sub-data) price)
        })
      )
      (update-track-stats track-id price false)
      (ok price)
    )
  )
)

(define-public (cancel-subscription (track-id uint))
  (let
    (
      (sub-data (unwrap! (map-get? active-subscriptions { track-id: track-id, subscriber: tx-sender }) ERR_SUBSCRIPTION_NOT_FOUND))
    )
    (asserts! (get is-active sub-data) ERR_NOT_SUBSCRIBED)
    (begin
      (map-set active-subscriptions
        { track-id: track-id, subscriber: tx-sender }
        (merge sub-data { is-active: false })
      )
      (update-track-stats track-id u0 false)
      (var-set total-subscriptions (- (var-get total-subscriptions) u1))
      (ok true)
    )
  )
)

(define-private (update-track-stats (track-id uint) (revenue uint) (is-new bool))
  (let
    (
      (current-stats (default-to { count: u0, total-revenue: u0 } 
                      (map-get? track-subscriber-count { track-id: track-id })))
    )
    (begin
      (map-set track-subscriber-count
        { track-id: track-id }
        {
          count: (if is-new (+ (get count current-stats) u1) (get count current-stats)),
          total-revenue: (+ (get total-revenue current-stats) revenue)
        }
      )
      true
    )
  )
)

(define-read-only (get-subscription-status (track-id uint) (subscriber principal))
  (map-get? active-subscriptions { track-id: track-id, subscriber: subscriber })
)

(define-read-only (get-tier-info (track-id uint) (tier-level uint))
  (map-get? subscription-tiers { track-id: track-id, tier-level: tier-level })
)

(define-read-only (get-track-stats (track-id uint))
  (map-get? track-subscriber-count { track-id: track-id })
)

(define-read-only (get-total-active-subscriptions)
  (ok (var-get total-subscriptions))
)