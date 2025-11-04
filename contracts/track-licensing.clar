(define-constant ERR_LICENSE_NOT_FOUND (err u200))
(define-constant ERR_LICENSE_EXPIRED (err u201))
(define-constant ERR_INVALID_LICENSE_TYPE (err u202))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u203))
(define-constant ERR_TRACK_NOT_FOUND (err u204))
(define-constant ERR_NOT_AUTHORIZED (err u205))

(define-constant LICENSE_TYPE_STREAMING u1)
(define-constant LICENSE_TYPE_COMMERCIAL u2)
(define-constant LICENSE_TYPE_EXCLUSIVE u3)

(define-map track-licenses
  { track-id: uint, license-type: uint }
  {
    price: uint,
    duration-blocks: uint,
    is-active: bool,
    sales-count: uint
  }
)

(define-map license-purchases
  { purchase-id: uint }
  {
    track-id: uint,
    license-type: uint,
    buyer: principal,
    purchase-block: uint,
    expiry-block: uint,
    amount-paid: uint
  }
)

(define-data-var next-purchase-id uint u1)

(define-public (configure-license (track-id uint) (license-type uint) (price uint) (duration-blocks uint))
  (let
    (
      (track-info (contract-call? .Music-Collaboration-Smart-Contract get-track track-id))
    )
    (asserts! (is-some track-info) ERR_TRACK_NOT_FOUND)
    (asserts! (or (is-eq license-type LICENSE_TYPE_STREAMING)
                  (or (is-eq license-type LICENSE_TYPE_COMMERCIAL)
                      (is-eq license-type LICENSE_TYPE_EXCLUSIVE))) ERR_INVALID_LICENSE_TYPE)
    (map-set track-licenses
      { track-id: track-id, license-type: license-type }
      {
        price: price,
        duration-blocks: duration-blocks,
        is-active: true,
        sales-count: u0
      }
    )
    (ok true)
  )
)

(define-public (purchase-license (track-id uint) (license-type uint))
  (let
    (
      (license-config (unwrap! (map-get? track-licenses { track-id: track-id, license-type: license-type }) ERR_LICENSE_NOT_FOUND))
      (purchase-id (var-get next-purchase-id))
      (current-block stacks-block-height)
      (expiry-block (+ current-block (get duration-blocks license-config)))
      (price (get price license-config))
    )
    (asserts! (get is-active license-config) ERR_LICENSE_NOT_FOUND)
    (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_PAYMENT)
    (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
    (map-set license-purchases
      { purchase-id: purchase-id }
      {
        track-id: track-id,
        license-type: license-type,
        buyer: tx-sender,
        purchase-block: current-block,
        expiry-block: expiry-block,
        amount-paid: price
      }
    )
    (map-set track-licenses
      { track-id: track-id, license-type: license-type }
      (merge license-config { sales-count: (+ (get sales-count license-config) u1) })
    )
    (var-set next-purchase-id (+ purchase-id u1))
    (ok purchase-id)
  )
)

(define-read-only (check-license-validity (purchase-id uint))
  (match (map-get? license-purchases { purchase-id: purchase-id })
    purchase-data (ok {
      is-valid: (>= (get expiry-block purchase-data) stacks-block-height),
      blocks-remaining: (if (>= (get expiry-block purchase-data) stacks-block-height)
        (- (get expiry-block purchase-data) stacks-block-height)
        u0),
      license-info: purchase-data
    })
    ERR_LICENSE_NOT_FOUND
  )
)

(define-read-only (get-license-config (track-id uint) (license-type uint))
  (map-get? track-licenses { track-id: track-id, license-type: license-type })
)

(define-read-only (get-purchase-info (purchase-id uint))
  (map-get? license-purchases { purchase-id: purchase-id })
)
