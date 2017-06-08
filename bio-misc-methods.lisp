;;; ------------------------------------------------------------
;;; Methods defining behaviors used across biocuration.
;;;
(:in-context exec-methods)

;;; ------------------------------
;;; WHAT-NEXT
;;; ------------------------------

;;; Gotta deal with the results for what next.
(kbop:method
 :matches ((what-next ?goal ?cpsa-reply-id))
 :pre ((report-for ?goal ?report))
 :on-ready ((:dbug "Time to REPLY with a REPORT for WHAT-NEXT")
            (:note ?report)
            (:report-status ?goal ?cpsa-reply-id ?report))
 :result success)

(kbop:method
 :matches ((evaluate ?goal ))
 :pre ((is-ask-what ONT::NAME ?goal ?what)
       (assoc-poss ?what ?who)
       (refers-to ?who ONT::SYS))
 :on-ready ((:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::NAME ?goal ?what)
       (assoc-poss ?what ?who)
       (refers-to ?who ONT::SYS))
 :on-ready ((:say "I'm Bob."))
 :result success)

(kbop:method
 :matches ((evaluate ?goal ))
 :pre ((is-ask-what ONT::STATUS ?goal ?what)
       (suchthat ?what ?st)
       (instance-of ?st ONT::HAVE-PROPERTY)
       (neutral ?st ?who)
       (refers-to ?who ONT::SYS))
 :on-ready ((:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::STATUS ?goal ?what)
       (suchthat ?what ?st)
       (instance-of ?st ONT::HAVE-PROPERTY)
       (neutral ?st ?who)
       (refers-to ?who ONT::SYS))
 :on-ready ((:say "I'm fine, thanks."))
 :result success)

