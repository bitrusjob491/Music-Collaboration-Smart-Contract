(define-constant ERR_TRACK_NOT_FOUND (err u500))
(define-constant ERR_NOT_COLLABORATOR (err u501))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u502))
(define-constant ERR_PROPOSAL_EXPIRED (err u503))
(define-constant ERR_ALREADY_VOTED (err u504))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u505))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u506))

(define-constant PROPOSAL_DURATION_BLOCKS u1008)
(define-constant VOTING_THRESHOLD u51)

(define-map proposals
  { proposal-id: uint }
  {
    track-id: uint,
    proposer: principal,
    proposal-type: uint,
    description: (string-ascii 200),
    created-block: uint,
    expiry-block: uint,
    total-votes-for: uint,
    total-votes-against: uint,
    is-executed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote-weight: uint, voted-for: bool }
)

(define-data-var next-proposal-id uint u1)

(define-public (create-proposal (track-id uint) (proposal-type uint) (description (string-ascii 200)))
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (collaborator-data (unwrap! (contract-call? .Music-Collaboration-Smart-Contract get-collaborator-info track-id tx-sender) ERR_NOT_COLLABORATOR))
      (current-block stacks-block-height)
      (expiry-block (+ current-block PROPOSAL_DURATION_BLOCKS))
    )
    (map-set proposals
      { proposal-id: proposal-id }
      {
        track-id: track-id,
        proposer: tx-sender,
        proposal-type: proposal-type,
        description: description,
        created-block: current-block,
        expiry-block: expiry-block,
        total-votes-for: u0,
        total-votes-against: u0,
        is-executed: false
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (cast-vote (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (track-id (get track-id proposal-data))
      (collaborator-data (unwrap! (contract-call? .Music-Collaboration-Smart-Contract get-collaborator-info track-id tx-sender) ERR_NOT_COLLABORATOR))
      (vote-weight (get percentage collaborator-data))
      (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (< stacks-block-height (get expiry-block proposal-data)) ERR_PROPOSAL_EXPIRED)
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote-weight: vote-weight, voted-for: vote-for }
    )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal-data {
        total-votes-for: (if vote-for (+ (get total-votes-for proposal-data) vote-weight) (get total-votes-for proposal-data)),
        total-votes-against: (if vote-for (get total-votes-against proposal-data) (+ (get total-votes-against proposal-data) vote-weight))
      })
    )
    (ok true)
  )
)

(define-read-only (get-proposal-info (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote-status (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (check-proposal-result (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal-data (ok {
      passed: (>= (get total-votes-for proposal-data) VOTING_THRESHOLD),
      votes-for: (get total-votes-for proposal-data),
      votes-against: (get total-votes-against proposal-data),
      is-expired: (>= stacks-block-height (get expiry-block proposal-data)),
      is-executed: (get is-executed proposal-data)
    })
    ERR_PROPOSAL_NOT_FOUND
  )
)
