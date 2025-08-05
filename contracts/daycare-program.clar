;; Adult Day Care Program Management Contract
;; Coordinates services for seniors needing daytime supervision

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-PROGRAM-NOT-FOUND (err u203))
(define-constant ERR-ENROLLMENT-NOT-FOUND (err u204))

;; Data Variables
(define-data-var next-participant-id uint u1)
(define-data-var next-program-id uint u1)
(define-data-var next-enrollment-id uint u1)

;; Data Maps
(define-map participants uint {
  name: (string-ascii 100),
  age: uint,
  medical-conditions: (string-ascii 500),
  emergency-contact: (string-ascii 100),
  care-level: (string-ascii 20),
  active: bool
})

(define-map daycare-programs uint {
  name: (string-ascii 100),
  description: (string-ascii 300),
  capacity: uint,
  current-enrollment: uint,
  daily-rate: uint,
  schedule: (string-ascii 100),
  active: bool
})

(define-map enrollments uint {
  participant-id: uint,
  program-id: uint,
  start-date: (string-ascii 20),
  end-date: (string-ascii 20),
  status: (string-ascii 20),
  monthly-cost: uint,
  care-plan: (string-ascii 500),
  created-at: uint
})

(define-map attendance-records uint {
  enrollment-id: uint,
  date: (string-ascii 20),
  check-in-time: (string-ascii 10),
  check-out-time: (string-ascii 10),
  activities-participated: (string-ascii 300),
  notes: (string-ascii 500)
})

;; Authorization check
(define-private (is-authorized)
  (is-eq tx-sender CONTRACT-OWNER))

;; Register a new participant
(define-public (register-participant (name (string-ascii 100))
                                   (age uint)
                                   (medical-conditions (string-ascii 500))
                                   (emergency-contact (string-ascii 100))
                                   (care-level (string-ascii 20)))
  (let ((participant-id (var-get next-participant-id)))
    (asserts! (> age u60) ERR-INVALID-INPUT)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (map-set participants participant-id {
      name: name,
      age: age,
      medical-conditions: medical-conditions,
      emergency-contact: emergency-contact,
      care-level: care-level,
      active: true
    })
    (var-set next-participant-id (+ participant-id u1))
    (ok participant-id)))

;; Create a new daycare program
(define-public (create-program (name (string-ascii 100))
                              (description (string-ascii 300))
                              (capacity uint)
                              (daily-rate uint)
                              (schedule (string-ascii 100)))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (let ((program-id (var-get next-program-id)))
      (asserts! (> capacity u0) ERR-INVALID-INPUT)
      (map-set daycare-programs program-id {
        name: name,
        description: description,
        capacity: capacity,
        current-enrollment: u0,
        daily-rate: daily-rate,
        schedule: schedule,
        active: true
      })
      (var-set next-program-id (+ program-id u1))
      (ok program-id))))

;; Enroll participant in program
(define-public (enroll-participant (participant-id uint)
                                  (program-id uint)
                                  (start-date (string-ascii 20))
                                  (care-plan (string-ascii 500)))
  (let ((enrollment-id (var-get next-enrollment-id))
        (participant (map-get? participants participant-id))
        (program (map-get? daycare-programs program-id)))
    (asserts! (is-some participant) ERR-PARTICIPANT-NOT-FOUND)
    (asserts! (is-some program) ERR-PROGRAM-NOT-FOUND)
    (asserts! (get active (unwrap-panic participant)) ERR-INVALID-INPUT)
    (asserts! (get active (unwrap-panic program)) ERR-INVALID-INPUT)
    (asserts! (< (get current-enrollment (unwrap-panic program))
                 (get capacity (unwrap-panic program))) ERR-INVALID-INPUT)
    (map-set enrollments enrollment-id {
      participant-id: participant-id,
      program-id: program-id,
      start-date: start-date,
      end-date: "",
      status: "active",
      monthly-cost: (* (get daily-rate (unwrap-panic program)) u22),
      care-plan: care-plan,
      created-at: block-height
    })
    (map-set daycare-programs program-id
      (merge (unwrap-panic program)
             {current-enrollment: (+ (get current-enrollment (unwrap-panic program)) u1)}))
    (var-set next-enrollment-id (+ enrollment-id u1))
    (ok enrollment-id)))

;; Record daily attendance
(define-public (record-attendance (enrollment-id uint)
                                 (date (string-ascii 20))
                                 (check-in-time (string-ascii 10))
                                 (check-out-time (string-ascii 10))
                                 (activities-participated (string-ascii 300))
                                 (notes (string-ascii 500)))
  (let ((enrollment (map-get? enrollments enrollment-id)))
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (is-some enrollment) ERR-ENROLLMENT-NOT-FOUND)
    (map-set attendance-records enrollment-id {
      enrollment-id: enrollment-id,
      date: date,
      check-in-time: check-in-time,
      check-out-time: check-out-time,
      activities-participated: activities-participated,
      notes: notes
    })
    (ok true)))

;; Update enrollment status
(define-public (update-enrollment-status (enrollment-id uint)
                                        (status (string-ascii 20))
                                        (end-date (string-ascii 20)))
  (let ((enrollment (map-get? enrollments enrollment-id)))
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (is-some enrollment) ERR-ENROLLMENT-NOT-FOUND)
    (map-set enrollments enrollment-id
      (merge (unwrap-panic enrollment) {status: status, end-date: end-date}))
    (ok true)))

;; Get participant information
(define-read-only (get-participant (participant-id uint))
  (map-get? participants participant-id))

;; Get program information
(define-read-only (get-program (program-id uint))
  (map-get? daycare-programs program-id))

;; Get enrollment details
(define-read-only (get-enrollment (enrollment-id uint))
  (map-get? enrollments enrollment-id))

;; Get attendance record
(define-read-only (get-attendance (enrollment-id uint))
  (map-get? attendance-records enrollment-id))
