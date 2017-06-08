;;;; Support for envisioning structures.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; Envision
;;;
;;; We take the envisionment as an argument here (instead of looking
;;; it up on the goal) so that we can try envisioning things without
;;; actually committing to it for real.
;;;
;;; Thus, when we fail any part of the envisionment, we can still
;;; proceed with the old one.

;; We have already envisioned it, nothing to do here.
(kbop:method
 :matches ((envision ?goal ?envisionment))
 :pre ((envisions ?envisionment ?structure))
 :result success)

;; If the envisionment didn't already exist, hallucinate it now.
(kbop:method
 :matches ((envision ?envisionment))
 :pre ((:uninferrable (envisions ?envisionment ?structure))
       (:uninferrable (get-structure-description ?goal ?structure)))
 :on-ready ((:note "No structure to envision."))
 :result success)

;; Hallucinate the structure.
 (kbop:method
 :matches ((envision ?goal ?envisionment))
 :pre ((:uninferrable (envisions ?envisionment ?structure))
       (get-structure-description ?goal ?structure))
 :on-ready ((:dbug "Time to envision a " ?structure)
            (:store (:sub-context blocksworld-rules ?envisionment))
            (:envision ?structure ?envisionment ?envisionment)
            (:store-query-result (touching-horizontal ?x ?y) ?envisionment)
            (:store-query-result (between ?x ?y ?z) ?envisionment)
            (:store-query-result (x-greater ?x ?y) ?envisionment)
            ;; We store this as an indication that the envisionment
            ;; has happened.
            (:store (envisions ?envisionment ?structure)))
 :result success)


;;; ------------------------------------------------------------
;;; Revise envisionment (Renvision)

(kbop:method
 :matches ((renvision ?create-goal ?new-envisionment))
 :pre ((:uninferrable (envisionment ?create-goal ?envisionment)))
 :on-ready ((:store (renvision-result ?goal NO-PRIOR-ENVISIONMENT)))
 :result success)

(kbop:method
 :matches ((renvision ?create-goal ?new-envisionment))
 :pre ((envisionment ?create-goal ?envisionment))
 :on-ready ((:dbug "Cloning envisionment" ?envisionment "into" ?new-envisionment)
            ;; Clone the previous envisionment and forward-chain to modify the new.
            (:clone-context ?envisionment ?new-envisionment)
            ;; Store the previous as a *past* envisionment.
            (:store (prior-envisionment ?new-envisionment ?envisionment))
            ;; Store an indication that all is well.
            (:store (renvision-result ?new-envisionment OK)))
 :result success)


