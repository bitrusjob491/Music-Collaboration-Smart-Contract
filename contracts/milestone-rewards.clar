(define-constant ERR_TRACK_NOT_FOUND (err u300))
(define-constant ERR_MILESTONE_NOT_REACHED (err u301))
(define-constant ERR_MILESTONE_ALREADY_CLAIMED (err u302))
(define-constant ERR_INSUFFICIENT_POOL_FUNDS (err u303))
(define-constant ERR_NOT_COLLABORATOR (err u304))

(define-constant MILESTONE_BRONZE u1000000000)
(define-constant MILESTONE_SILVER u5000000000)
(define-constant MILESTONE_GOLD u10000000000)
(define-constant MILESTONE_PLATINUM u25000000000)

(define-constant REWARD_BRONZE u50000000)
(define-constant REWARD_SILVER u200000000)
(define-constant REWARD_GOLD u500000000)
(define-constant REWARD_PLATINUM u1500000000)

(define-map milestone-status
  { track-id: uint, milestone-level: uint }
  { claimed: bool, claim-block: uint }
)

(define-map reward-pool
  { pool-type: uint }
  { balance: uint }
)

(define-map collaborator-rewards
  { track-id: uint, collaborator: principal }
  { total-milestone-rewards: uint, last-claim-block: uint }
)

(define-data-var total-milestone-funds uint u0)

(define-public (fund-reward-pool (amount uint))
  (let
    (
      (current-pool (default-to { balance: u0 } (map-get? reward-pool { pool-type: u1 })))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set reward-pool
      { pool-type: u1 }
      { balance: (+ (get balance current-pool) amount) }
    )
    (var-set total-milestone-funds (+ (var-get total-milestone-funds) amount))
    (ok amount)
  )
)

(define-public (check-and-unlock-milestone (track-id uint))
  (let
    (
      (track-info (unwrap! (contract-call? .Music-Collaboration-Smart-Contract get-track track-id) ERR_TRACK_NOT_FOUND))
      (total-earnings (get total-earnings track-info))
      (milestone-level (get-milestone-level total-earnings))
    )
    (if (> milestone-level u0)
      (unlock-milestone-reward track-id milestone-level)
      (ok false)
    )
  )
)

(define-private (get-milestone-level (earnings uint))
  (if (>= earnings MILESTONE_PLATINUM)
    u4
    (if (>= earnings MILESTONE_GOLD)
      u3
      (if (>= earnings MILESTONE_SILVER)
        u2
        (if (>= earnings MILESTONE_BRONZE)
          u1
          u0
        )
      )
    )
  )
)

(define-private (unlock-milestone-reward (track-id uint) (milestone-level uint))
  (let
    (
      (milestone-data (map-get? milestone-status { track-id: track-id, milestone-level: milestone-level }))
      (reward-amount (get-reward-amount milestone-level))
    )
    (if (is-none milestone-data)
      (begin
        (map-set milestone-status
          { track-id: track-id, milestone-level: milestone-level }
          { claimed: false, claim-block: stacks-block-height }
        )
        (ok true)
      )
      (ok false)
    )
  )
)

(define-private (get-reward-amount (milestone-level uint))
  (if (is-eq milestone-level u4)
    REWARD_PLATINUM
    (if (is-eq milestone-level u3)
      REWARD_GOLD
      (if (is-eq milestone-level u2)
        REWARD_SILVER
        REWARD_BRONZE
      )
    )
  )
)

(define-public (claim-milestone-reward (track-id uint) (milestone-level uint))
  (let
    (
      (milestone-data (unwrap! (map-get? milestone-status { track-id: track-id, milestone-level: milestone-level }) ERR_MILESTONE_NOT_REACHED))
      (collaborator-data (unwrap! (contract-call? .Music-Collaboration-Smart-Contract get-collaborator-info track-id tx-sender) ERR_NOT_COLLABORATOR))
      (reward-amount (get-reward-amount milestone-level))
      (collaborator-share (/ (* reward-amount (get percentage collaborator-data)) u100))
      (pool-data (unwrap! (map-get? reward-pool { pool-type: u1 }) ERR_INSUFFICIENT_POOL_FUNDS))
      (current-rewards (default-to { total-milestone-rewards: u0, last-claim-block: u0 } 
                       (map-get? collaborator-rewards { track-id: track-id, collaborator: tx-sender })))
    )
    (asserts! (not (get claimed milestone-data)) ERR_MILESTONE_ALREADY_CLAIMED)
    (asserts! (>= (get balance pool-data) collaborator-share) ERR_INSUFFICIENT_POOL_FUNDS)
    (try! (as-contract (stx-transfer? collaborator-share tx-sender tx-sender)))
    (map-set milestone-status
      { track-id: track-id, milestone-level: milestone-level }
      { claimed: true, claim-block: stacks-block-height }
    )
    (map-set reward-pool
      { pool-type: u1 }
      { balance: (- (get balance pool-data) collaborator-share) }
    )
    (map-set collaborator-rewards
      { track-id: track-id, collaborator: tx-sender }
      { 
        total-milestone-rewards: (+ (get total-milestone-rewards current-rewards) collaborator-share),
        last-claim-block: stacks-block-height
      }
    )
    (ok collaborator-share)
  )
)

(define-read-only (get-milestone-status (track-id uint) (milestone-level uint))
  (map-get? milestone-status { track-id: track-id, milestone-level: milestone-level })
)

(define-read-only (get-available-milestones (track-id uint))
  (match (contract-call? .Music-Collaboration-Smart-Contract get-track track-id)
    track-info (let
      (
        (earnings (get total-earnings track-info))
        (max-level (get-milestone-level earnings))
      )
      (ok { max-milestone-level: max-level, earnings: earnings })
    )
    ERR_TRACK_NOT_FOUND
  )
)

(define-read-only (get-reward-pool-balance)
  (match (map-get? reward-pool { pool-type: u1 })
    pool-data (ok (get balance pool-data))
    (ok u0)
  )
)

(define-read-only (get-collaborator-milestone-rewards (track-id uint) (collaborator principal))
  (map-get? collaborator-rewards { track-id: track-id, collaborator: collaborator })
)
