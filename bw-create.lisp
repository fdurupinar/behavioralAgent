;;;; Support for CREATE (or BUILD) goals. This is almost always the
;;;; top-level activity in the blocksworld domain.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; CREATE without any specific thing to build.

;;; If we don't have an affected-result, this is a general purpose
;;; goal to create something. We are okay with that, though we won't
;;; be able to make suggestions about what to do next.
;;;
;;; This shows up when the user says "Put block 6 on the table." TRIPS
;;; clarifies with the user, do you mean to create something? If the
;;; user says "yes", we get an empty create goal like this.
;;;
(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-create-goal ?goal)
       (:uninferrable (affected-result-eci ?goal ?eci)))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal ACCEPTABLE)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-create-goal ?goal)
       (:uninferrable (affected-result-eci ?goal ?eci)))
 :on-ready ((:note "nothing specific to build.")
            ;; FIXME We could be asking the user what they want to
            ;; build, or what they want to do next. I don't quite know
            ;; how to specify that. So, for the sake of unblocking the
            ;; system, we go ahead defer to the user.
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::waiting-for-user))))
 :result success)


;;; ------------------------------------------------------------
;;; CREATE with an intended result.
;;;
;;; This is what we get when the user says something like: "Let's
;;; build stairs."
;;;

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-create-goal ?goal)
       (affected-result-eci ?goal ?eci)
       (:uninferrable (get-structure-description ?goal ?desc)))
 :on-ready ((:note "Don't understand structure")
            (:subgoal (prepare-dont-understand-structure-result ?goal))))

;;; [jrye:20170309.1439CST] We added this one-off case where we want
;;; to include additional information with the failure
;;; result. Ultimately we would prefer to have a general way to record
;;; and report that detail. I'm afraid that is something for later.
(kbop:method
 :matches ((prepare-dont-understand-structure-result ?goal))
 :pre ((what ?goal ?wid)
       (affected-result ?wid ?aid)
       (lex ?aid ?lex))
 :on-ready ((:store (evaluate-result ?goal (DONT-UNDERSTAND-STRUCTURE :detail ?lex))))
 :result success)

(kbop:method
 :matches ((prepare-dont-understand-structure-result ?goal))
 :pre ((:uninferrable
        (what ?goal ?wid)
        (affected-result ?wid ?aid)
        (lex ?aid ?lex)))
 :on-ready ((:store (evaluate-result ?goal (DONT-UNDERSTAND-STRUCTURE))))
 :result success)

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-create-goal ?goal)
       (affected-result-eci ?goal ?eci)
       (get-structure-description ?goal ?desc))
 :on-ready ((:gentemp ?envisionment "envision")
            (:subgoal (envision ?goal ?envisionment))
            ;; If necessary, constrain the direction of the structure.
            (:subgoal (maybe-constrain-direction ?goal ?envisionment))
            ;; Collect any constraints and apply them to the
            ;; envisionment.
            (:subgoal (find-and-apply-constraints ?goal ?envisionment))
            ;; Verify and plan.
            (:subgoal (verify ?envisionment))
            (:subgoal (plan ?goal ?envisionment))
            ;; Determine and report the evaluate result.
            (:subgoal (report-plan-eval ?goal ?envisionment))
            ))

;; FIXME This should actually look at the constraints to see if there
;; is any direction information. Here we are just making all rows (and
;; only rows) have an implicit left-right ordering.
(kbop:method
 :matches ((maybe-constrain-direction ?goal ?envisionment))
 :pre ((affected-result-eci ?goal ?eci-id)
       (type ?eci-id row))
 :on-ready ((:note "left-right row")
            (:subgoal (make-left-right ?envisionment)))
 :result success)

(kbop:method
 :matches ((maybe-constrain-direction ?goal ?envisionment))
 :pre ((:uninferrable
        (affected-result-eci ?goal ?eci-id)
        (type ?eci-id row)))
 :on-ready ((:note "not a row"))
 :result success)

;; If we had a failure, report it.
(kbop:method
 :matches ((report-plan-eval ?goal ?envisionment))
 :pre ((determine-plan-eval-failure ?envisionment ?result))
 :on-ready ((:store (evaluate-result ?goal ?result)))
 :result success)

;; If we didn't have a failure, this is a success. Commit to this
;; envisionment and call it successful.
(kbop:method
 :matches ((report-plan-eval ?goal ?envisionment))
 :pre ((:uninferrable (determine-plan-eval-failure ?envisionment ?result)))
 :on-ready ((:store (envisionment ?goal ?envisionment))
            (:make-log-entry envisionment ?envisionment)
            (:store (evaluate-result ?goal ACCEPTABLE)))
 :result success)

;; We know what we want to build, if we do not have a valid actor,
;; post a subgoal to determine one. If we do have a valid actor,
;; choose an action and proceed.
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-create-goal ?goal)
       (envisionment ?goal ?envisionment)
       (:uninferrable (get-valid-actor ?goal ?actor ?source)))
 :on-ready ((:dbug "Need to determine actor.")
            (:subgoal (determine-actor ?goal ?reply-id))))

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-create-goal ?goal)
       (envisionment ?goal ?envisionment)
       (get-valid-actor ?goal ?actor ?source))
 :on-ready ((:dbug "Time to orient and act." ?goal)
            ;; We have everything we need. Decide what to do and
            ;; propose it to the user.
            (:gentemp ?action "ACTION-")
            (:subgoal (orient-to-plan ?goal ?action))
            (:subgoal (what-next-for-action ?goal ?reply-id ?action))
            ))


;;; ------------------------------------------------------------
;;; Rules relating to CREATE goals.
;;;
(:in-context collab-context)

(<< (is-create-goal ?goal)
    (what ?goal ?what)
    (instance-of ?what ont::create))

;;; ------------------------------------------------------------
;;; Collect up the results of envision, verify, and plan to make an
;;; evaluate result.

;; Did not even envision it.
(<< (determine-plan-eval-failure ?envisionment ?result)
    (:uninferrable (envisions-structure ?envisionment ?structure))
    (:assign ?result UNABLE-TO-ENVISION))

;; Verification didn't even happen.
(<< (determine-plan-eval-failure ?envisionment ?result)
    (envisions-structure ?envisionment ?structure)
    (:uninferrable (verification-result ?envisionment ?anything))
    (:assign ?result UNABLE-TO-VERIFY))

;; If verification wasn't OK, that's the result.
(<< (determine-plan-eval-failure ?envisionment ?result)
    (envisions-structure ?envisionment ?structure)
    (:uninferrable (verification-result ?envisionment OK))
    (verification-result ?envisionment ?r)
    (:assign ?result ?r))

;; No problem with the verification, but we didn't make a plan.
(<< (determine-plan-eval-failure ?envisionment ?result)
    (envisions-structure ?envisionment ?structure)
    (verification-result ?envisionment OK)
    (:uninferrable (plan-for ?envisionment ?plan))
    (:assign ?result UNABLE-TO-PLAN))

(<< (envisions-structure ?envisionment ?structure)
    (envisions ?envisionment ?structure))

(<< (envisions-structure ?envisionment ?structure)
    (:uninferrable (envisions ?envisionment ?structure))
    (prior-envisionment ?envisionment ?prior)
    (envisions-structure ?prior ?structure))

;;; ------------------------------------------------------------
;;; Rules to build up structure descriptions

(<< (get-structure-description ?goal ?structure)
    (affected-result-eci ?goal ?eci-id)
    (get-eci-structure ?eci-id ?structure))

(<< (get-eci-structure ?eci-id ?structure)
    (type ?eci-id ?type)
    (:uninferrable (size ?eci-id ?size))
    (:cdr ?structure (list-fn ?type)))

(<< (get-eci-structure ?eci-id ?structure)
    (type ?eci-id ?type)
    (size ?eci-id ?size)
    (:cdr ?structure (list-fn ?type :size ?size)))

