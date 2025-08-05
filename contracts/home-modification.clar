;; Home Modification Assistance Contract
;; Helps seniors make accessibility improvements to their homes

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-HOMEOWNER-NOT-FOUND (err u401))
(define-constant ERR-INVALID-INPUT (err u402))
(define-constant ERR-REQUEST-NOT-FOUND (err u403))
(define-constant ERR-CONTRACTOR-NOT-FOUND (err u404))

;; Data Variables
(define-data-var next-homeowner-id uint u1)
(define-data-var next-contractor-id uint u1)
(define-data-var next-request-id uint u1)

;; Data Maps
(define-map homeowners uint {
  name: (string-ascii 100),
  address: (string-ascii 200),
  age: uint,
  income-level: (string-ascii 20),
  disability-status: (string-ascii 200),
  phone: (string-ascii 20),
  active: bool
})

(define-map contractors uint {
  name: (string-ascii 100),
  license-number: (string-ascii 50),
  specialties: (string-ascii 300),
  phone: (string-ascii 20),
  rating: uint,
  insurance-verified: bool,
  active: bool
})

(define-map modification-requests uint {
  homeowner-id: uint,
  contractor-id: uint,
  modification-type: (string-ascii 100),
  description: (string-ascii 500),
  estimated-cost: uint,
  funding-approved: uint,
  status: (string-ascii 20),
  priority-level: (string-ascii 20),
  created-at: uint
})

(define-map project-details uint {
  request-id: uint,
  start-date: (string-ascii 20),
  completion-date: (string-ascii 20),
  actual-cost: uint,
  materials-used: (string-ascii 500),
  inspection-passed: bool,
  homeowner-satisfaction: uint,
  photos-before: (string-ascii 200),
  photos-after: (string-ascii 200)
})

;; Authorization check
(define-private (is-authorized)
  (is-eq tx-sender CONTRACT-OWNER))

;; Register a new homeowner
(define-public (register-homeowner (name (string-ascii 100))
                                  (address (string-ascii 200))
                                  (age uint)
                                  (income-level (string-ascii 20))
                                  (disability-status (string-ascii 200))
                                  (phone (string-ascii 20)))
  (let ((homeowner-id (var-get next-homeowner-id)))
    (asserts! (> age u60) ERR-INVALID-INPUT)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len address) u0) ERR-INVALID-INPUT)
    (map-set homeowners homeowner-id {
      name: name,
      address: address,
      age: age,
      income-level: income-level,
      disability-status: disability-status,
      phone: phone,
      active: true
    })
    (var-set next-homeowner-id (+ homeowner-id u1))
    (ok homeowner-id)))

;; Register a new contractor
(define-public (register-contractor (name (string-ascii 100))
                                   (license-number (string-ascii 50))
                                   (specialties (string-ascii 300))
                                   (phone (string-ascii 20))
                                   (insurance-verified bool))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (let ((contractor-id (var-get next-contractor-id)))
      (map-set contractors contractor-id {
        name: name,
        license-number: license-number,
        specialties: specialties,
        phone: phone,
        rating: u5,
        insurance-verified: insurance-verified,
        active: true
      })
      (var-set next-contractor-id (+ contractor-id u1))
      (ok contractor-id))))

;; Submit modification request
(define-public (submit-request (homeowner-id uint)
                              (modification-type (string-ascii 100))
                              (description (string-ascii 500))
                              (estimated-cost uint)
                              (priority-level (string-ascii 20)))
  (let ((request-id (var-get next-request-id))
        (homeowner (map-get? homeowners homeowner-id)))
    (asserts! (is-some homeowner) ERR-HOMEOWNER-NOT-FOUND)
    (asserts! (get active (unwrap-panic homeowner)) ERR-INVALID-INPUT)
    (asserts! (> (len modification-type) u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-cost u0) ERR-INVALID-INPUT)
    (map-set modification-requests request-id {
      homeowner-id: homeowner-id,
      contractor-id: u0,
      modification-type: modification-type,
      description: description,
      estimated-cost: estimated-cost,
      funding-approved: u0,
      status: "pending",
      priority-level: priority-level,
      created-at: block-height
    })
    (var-set next-request-id (+ request-id u1))
    (ok request-id)))

;; Approve funding for request
(define-public (approve-funding (request-id uint) (approved-amount uint))
  (let ((request (map-get? modification-requests request-id)))
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (is-some request) ERR-REQUEST-NOT-FOUND)
    (asserts! (> approved-amount u0) ERR-INVALID-INPUT)
    (map-set modification-requests request-id
      (merge (unwrap-panic request)
             {funding-approved: approved-amount, status: "funded"}))
    (ok true)))

;; Assign contractor to request
(define-public (assign-contractor (request-id uint) (contractor-id uint))
  (let ((request (map-get? modification-requests request-id))
        (contractor (map-get? contractors contractor-id)))
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (is-some request) ERR-REQUEST-NOT-FOUND)
    (asserts! (is-some contractor) ERR-CONTRACTOR-NOT-FOUND)
    (asserts! (get active (unwrap-panic contractor)) ERR-INVALID-INPUT)
    (asserts! (get insurance-verified (unwrap-panic contractor)) ERR-INVALID-INPUT)
    (map-set modification-requests request-id
      (merge (unwrap-panic request)
             {contractor-id: contractor-id, status: "assigned"}))
    (ok true)))

;; Start project
(define-public (start-project (request-id uint)
                             (start-date (string-ascii 20))
                             (photos-before (string-ascii 200)))
  (let ((request (map-get? modification-requests request-id)))
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (is-some request) ERR-REQUEST-NOT-FOUND)
    (map-set project-details request-id {
      request-id: request-id,
      start-date: start-date,
      completion-date: "",
      actual-cost: u0,
      materials-used: "",
      inspection-passed: false,
      homeowner-satisfaction: u0,
      photos-before: photos-before,
      photos-after: ""
    })
    (map-set modification-requests request-id
      (merge (unwrap-panic request) {status: "in-progress"}))
    (ok true)))

;; Complete project
(define-public (complete-project (request-id uint)
                                (completion-date (string-ascii 20))
                                (actual-cost uint)
                                (materials-used (string-ascii 500))
                                (photos-after (string-ascii 200)))
  (let ((request (map-get? modification-requests request-id))
        (project (map-get? project-details request-id)))
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (is-some request) ERR-REQUEST-NOT-FOUND)
    (asserts! (is-some project) ERR-REQUEST-NOT-FOUND)
    (map-set project-details request-id
      (merge (unwrap-panic project) {
        completion-date: completion-date,
        actual-cost: actual-cost,
        materials-used: materials-used,
        photos-after: photos-after
      }))
    (map-set modification-requests request-id
      (merge (unwrap-panic request) {status: "completed"}))
    (ok true)))

;; Get homeowner information
(define-read-only (get-homeowner (homeowner-id uint))
  (map-get? homeowners homeowner-id))

;; Get contractor information
(define-read-only (get-contractor (contractor-id uint))
  (map-get? contractors contractor-id))

;; Get modification request
(define-read-only (get-request (request-id uint))
  (map-get? modification-requests request-id))

;; Get project details
(define-read-only (get-project-details (request-id uint))
  (map-get? project-details request-id))
