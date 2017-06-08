;;;; Define support for things common to both domains.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; Define fallback scheme for WHAT-NEXT
;;;
;;; All the "real" WHAT-NEXT methods should have the default (nil) or
;;; some meaningful priority. Here we define a fallback so that if we
;;; truly have nothing else we can do, we still reply to the CPSA.
;;;
;;; This is extremely low priority. We should do it only after
;;; exhausting everything else. Maybe we should even use some
;;; most-negative-number constant.

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :priority -99
 :on-ready ((:note "Fallback, unhandled goal")
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON UNHANDLED-GOAL))))
 :result success)


;;; ------------------------------------------------------------
;;; Reporting answers from the BA
;;;
;;; When we get an answer, report to the CPSA. If the question was an
;;; ASK-WH, we send back the answer-id. If the question was an ASK-IF,
;;; we need to send back ONT::TRUE or ONT::FALSE. If there was an
;;; error, we send back a failure.

;;; ------------------------------
;;; For ASK-WH, send the answer-id.

(kbop:method
 :matches ((report-answer ?query-id ?what ?goal ?reply-id))
 :priority 1
 :pre ((answer ?query-id ?answer-id)
       (kqml-predicate ?answer-id FAILURE))
 :on-ready ((:note "answer indicated failure")
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON ?answer-id))))
 :result success)

(kbop:method
 :matches ((report-answer ?query-id ?what ?goal ?reply-id))
 :pre ((answer ?query-id ?answer-id))
 :on-ready ((:report-status
             ?goal ?reply-id
             (REPORT :content
                     (ANSWER :TO ?goal
                             :WHAT ?what
                             ;; I think this is supposed to be defined
                             ;; in a context around here. Do we
                             ;; actually need it?
                             ;;
                             ;; :QUERY ?query
                             :VALUE ?answer-id
                             ;; :JUSTIFICATION ?query-id
                             ))))
 :result success)

;;; ------------------------------
;;; For ASK-IF, send ONT::TRUE or ONT::FALSE.

(kbop:method
 :matches ((report-answer ?query-id ?goal ?reply-id))
 :priority 1
 :pre ((answer ?query-id ?answer-id)
       (kqml-predicate ?answer-id FAILURE))
 :on-ready ((:note "answer indicated failure")
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON ?answer-id))))
 :result success)

(kbop:method
 :matches ((report-answer ?query-id ?goal ?reply-id))
 :pre ((answer ?query-id ?answer-id))
 :on-ready ((:report-status
             ?goal ?reply-id
             (REPORT :content
                     (ANSWER :TO ?goal
                             ;; I think this is supposed to be defined
                             ;; in a context around here. Do we
                             ;; actually need it?
                             ;;
                             ;; :QUERY ?query
                             :VALUE ?answer-id
                             ;; :JUSTIFICATION ?query-id
                             ))))
 :result success)

