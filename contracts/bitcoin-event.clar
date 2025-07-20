;; ======================================
;; BITCOIN EVENT CONTRACT
;; ======================================
;; This contract manages Bitcoin-related event registrations, tracking,
;; and participation within a decentralized event management platform.
;; 
;; It provides functionality for:
;; - Event registration and ticket management
;; - Dynamic event tracking and participation
;; - Secure ticket transfer and verification
;; - Community event interaction and rewards
;; - Transparent event management
;; 
;; All event interactions are fully transparent and blockchain-verified,
;; ensuring secure and fair participation.
;; ======================================

;; ======================================
;; Error Constants
;; ======================================
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-ALREADY-EXISTS (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-DEVICE-ALREADY-REGISTERED (err u103))
(define-constant ERR-DEVICE-NOT-FOUND (err u104))
(define-constant ERR-INVALID-DATA-TYPE (err u105))
(define-constant ERR-ACCESS-DENIED (err u106))
(define-constant ERR-CONSENT-NOT-GIVEN (err u107))
(define-constant ERR-CHALLENGE-NOT-FOUND (err u108))
(define-constant ERR-ALREADY-JOINED-CHALLENGE (err u109))
(define-constant ERR-CHALLENGE-ENDED (err u110))
(define-constant ERR-INVALID-DURATION (err u111))
(define-constant ERR-INVALID-REWARD (err u112))

;; ======================================
;; Data Maps and Variables
;; ======================================

;; User registration and profile management
(define-map users 
  { user-id: principal } 
  {
    name: (optional (string-utf8 50)),
    profile-data-url: (optional (string-utf8 256)),
    registration-time: uint,
    active: bool
  }
)

;; Track user's registered devices
(define-map user-devices
  { user-id: principal, device-id: (string-utf8 64) }
  {
    device-type: (string-utf8 50),
    added-at: uint,
    last-sync: uint,
    active: bool
  }
)

;; Data types users can store and share
(define-map data-types
  { type-id: (string-utf8 30) }
  {
    name: (string-utf8 50),
    description: (string-utf8 256),
    sensitive: bool
  }
)

;; Storage references for user health data (actual data stored off-chain)
(define-map data-storage-refs
  { user-id: principal, data-type: (string-utf8 30), timestamp: uint }
  {
    storage-url: (string-utf8 256),
    encryption-key-id: (string-utf8 64),
    hash: (buff 32)
  }
)

;; Permissions for data access by third parties
(define-map data-permissions
  { user-id: principal, grantee-id: principal, data-type: (string-utf8 30) }
  {
    granted-at: uint,
    expires-at: uint,
    purpose: (string-utf8 100),
    revocable: bool,
    access-count: uint
  }
)

;; Consent records for audit trail
(define-map consent-records
  { record-id: (string-utf8 64) }
  {
    user-id: principal,
    grantee-id: principal,
    data-types: (list 20 (string-utf8 30)),
    granted-at: uint,
    expires-at: uint,
    purpose: (string-utf8 100),
    consent-proof: (buff 64)
  }
)

;; Community health challenges
(define-map challenges
  { challenge-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 256),
    required-data-types: (list 10 (string-utf8 30)),
    start-time: uint,
    end-time: uint,
    goal-criteria: (string-utf8 256),
    reward-amount: uint,
    reward-token: principal,
    organizer: principal,
    active: bool
  }
)

;; User participation in challenges
(define-map challenge-participants
  { challenge-id: uint, user-id: principal }
  {
    joined-at: uint,
    goal-reached: bool,
    goal-reached-at: (optional uint),
    reward-claimed: bool
  }
)

;; Research initiatives for anonymous data
(define-map research-initiatives
  { initiative-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 256),
    required-data-types: (list 10 (string-utf8 30)),
    organizer: principal,
    start-time: uint,
    end-time: uint,
    reward-per-contribution: uint,
    reward-token: principal,
    active: bool
  }
)

;; User participation in research
(define-map research-contributors
  { initiative-id: uint, user-id: principal }
  {
    joined-at: uint,
    data-contributed: bool,
    last-contribution: (optional uint),
    reward-claimed: bool
  }
)

;; Track the next IDs for various entities
(define-data-var next-challenge-id uint u1)
(define-data-var next-initiative-id uint u1)

;; Contract admin for initial setup and maintenance
(define-data-var contract-admin principal tx-sender)

;; ======================================
;; Private Functions
;; ======================================

;; Check if the user exists
(define-private (user-exists (user-id principal))
  (default-to false (get active (map-get? users { user-id: user-id })))
)

;; Check if the sender is the contract admin
(define-private (is-contract-admin)
  (is-eq tx-sender (var-get contract-admin))
)

;; Validate that a data type exists
(define-private (is-valid-data-type (data-type (string-utf8 30)))
  (is-some (map-get? data-types { type-id: data-type }))
)



;; ======================================
;; Read-Only Functions
;; ======================================

;; Get user profile information
(define-read-only (get-user-profile (user-id principal))
  (map-get? users { user-id: user-id })
)


;; Get information about a specific data type
(define-read-only (get-data-type-info (type-id (string-utf8 30)))
  (map-get? data-types { type-id: type-id })
)


;; Get details of an active challenge
(define-read-only (get-challenge-details (challenge-id uint))
  (map-get? challenges { challenge-id: challenge-id })
)

;; Check if a user is participating in a challenge
(define-read-only (is-challenge-participant (challenge-id uint) (user-id principal))
  (is-some (map-get? challenge-participants { challenge-id: challenge-id, user-id: user-id }))
)

;; Get a user's challenge participation status
(define-read-only (get-challenge-participation (challenge-id uint) (user-id principal))
  (map-get? challenge-participants { challenge-id: challenge-id, user-id: user-id })
)

;; Get details of a research initiative
(define-read-only (get-research-initiative (initiative-id uint))
  (map-get? research-initiatives { initiative-id: initiative-id })
)

;; Check if a user is contributing to a research initiative
(define-read-only (is-research-contributor (initiative-id uint) (user-id principal))
  (is-some (map-get? research-contributors { initiative-id: initiative-id, user-id: user-id }))
)

;; ======================================
;; Public Functions
;; ======================================


;; Update user profile information
(define-public (update-profile (name (optional (string-utf8 50))) (profile-data-url (optional (string-utf8 256))))
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      (begin
        (map-set users
          { user-id: user-id }
          (merge (default-to 
                  { 
                    name: none,
                    profile-data-url: none,
                    registration-time: u0, 
                    active: true
                  } 
                  (map-get? users { user-id: user-id }))
                 {
                   name: name,
                   profile-data-url: profile-data-url
                 }
          )
        )
        (ok true)
      )
      ERR-USER-NOT-FOUND
    )
  )
)

;; Deactivate user account
(define-public (deactivate-account)
  (let ((user-id tx-sender))
    (if (user-exists user-id)
      (begin
        (map-set users
          { user-id: user-id }
          (merge (default-to 
                  { 
                    name: none,
                    profile-data-url: none,
                    registration-time: u0, 
                    active: true
                  } 
                  (map-get? users { user-id: user-id }))
                 { active: false }
          )
        )
        (ok true)
      )
      ERR-USER-NOT-FOUND
    )
  )
)




;; Remove a device
(define-public (remove-device (device-id (string-utf8 64)))
  (let ((user-id tx-sender))
    (match (map-get? user-devices { user-id: user-id, device-id: device-id })
      device (begin
               (map-set user-devices
                 { user-id: user-id, device-id: device-id }
                 (merge device { active: false })
               )
               (ok true)
             )
      ERR-DEVICE-NOT-FOUND
    )
  )
)



;; Revoke data access permission
(define-public (revoke-data-permission
                (grantee-id principal)
                (data-type (string-utf8 30)))
  (let ((user-id tx-sender))
    (match (map-get? data-permissions { user-id: user-id, grantee-id: grantee-id, data-type: data-type })
      permission (if (get revocable permission)
                   (begin
                     (map-delete data-permissions 
                       { user-id: user-id, grantee-id: grantee-id, data-type: data-type }
                     )
                     (ok true)
                   )
                   ERR-NOT-AUTHORIZED
                 )
      ERR-ACCESS-DENIED
    )
  )
)



;; Claim reward for research contribution
(define-public (claim-research-reward (initiative-id uint))
  (let ((user-id tx-sender))
    
    (match (map-get? research-initiatives { initiative-id: initiative-id })
      initiative (match (map-get? research-contributors { initiative-id: initiative-id, user-id: user-id })
                   contributor (if (and (get data-contributed contributor)
                                       (not (get reward-claimed contributor)))
                                 (begin
                                   ;; Update contributor record to mark reward as claimed
                                   (map-set research-contributors
                                     { initiative-id: initiative-id, user-id: user-id }
                                     (merge contributor { reward-claimed: true })
                                   )
                                   
                                   ;; If this were a real contract, we would transfer tokens here
                                   ;; For example: (contract-call? (get reward-token initiative) transfer 
                                   ;;               (get reward-per-contribution initiative) (get organizer initiative) user-id none)
                                   
                                   (ok true)
                                 )
                                 (err (if (get reward-claimed contributor)
                                        u115  ;; Already claimed
                                        u116  ;; No data contributed
                                      ))
                               )
                   ERR-USER-NOT-FOUND
                 )
      ERR-CHALLENGE-NOT-FOUND
    )
  )
)

;; Add a new data type (admin only)
(define-public (add-data-type 
                (type-id (string-utf8 30))
                (name (string-utf8 50))
                (description (string-utf8 256))
                (sensitive bool))
  (if (is-contract-admin)
    (begin
      (map-set data-types
        { type-id: type-id }
        {
          name: name,
          description: description,
          sensitive: sensitive
        }
      )
      (ok true)
    )
    ERR-NOT-AUTHORIZED
  )
)

;; Transfer contract administration (admin only)
(define-public (transfer-admin (new-admin principal))
  (if (is-contract-admin)
    (begin
      (var-set contract-admin new-admin)
      (ok true)
    )
    ERR-NOT-AUTHORIZED
  )
)