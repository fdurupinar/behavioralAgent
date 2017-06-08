(:in-context exec-methods)

;; ------------------------------------------------------------
;; Make a plan for the envisionment (once there is an envisionment to
;; plan for). We don't need to check for verified here.
(kbop:method
 :matches ((plan ?goal ?envisionment))
 :pre ((:uninferrable (plan-for ?envisionment ?plan-name)))
 :on-ready ((:gentemp ?plan-name "plan")
            (:gentemp ?plan-context "plan-context")
            (:gentemp ?goal-context "goal-state")
            (:dbug "I have envisioned" ?goal "in" ?envisionment)
            (:dbug "My goal context will be" ?goal-context)
            (:clone-context ?envisionment ?goal-context)
            (:clear-ecis ?goal-context)
            (:dbug "Will plan" ?plan-name "in" ?plan-context)
            (:regression-plan ?goal-context
                              ((:remove ?x (and (isa ?x block)
                                                (not (on ?y ?x))
                                                (not (between ?x ?a ?b)))))
                              ?plan-name ?plan-context)
            (:store (plan-for ?envisionment ?plan-context))
            (:note "plan context:" ?plan-context)
            ;; (:store (evaluate-result ?goal ACCEPTABLE))
            )
 :result success)

;; If we alrady had a plan, call it good.
(kbop:method
 :matches ((plan ?goal ?envisionment))
 :pre ((plan-for ?envisionment ?plan-name))
 :result success)

;; ------------------------------------------------------------
;; Manage progress against the plan.

(kbop:method
 :matches ((orient-to-plan ?goal-id ?action))
 :pre ((envisionment ?goal-id ?envisionment)
       (plan-for ?envisionment ?plan)
       (:plan-localize scene ?plan ?best-sat-mapping ?desired-mappings)
       (:different ?desired-mappings (list-fn))
       (:mapping-target-context ?best-sat-mapping ?best-sat-context)
       (:elt-at ?desired-mappings 0 ?desired-mapping)
       (:mapping-target-context ?desired-mapping ?desired-context)
       (:aggregate ?infs ?inf (:mapping-base-inference ?desired-mapping ?inf))
       (:aggregate ?ignored-correspondences ?corr
                   (:in scene (eci-ignore ?corr))
                   (:mapping-correspondence ?desired-mapping ?corr ?other)))
 :on-ready ((:gentemp ?inf-context "inf-context")
            (:gentemp ?todo-context "todo-context")
            (:gentemp ?trans-context "trans-context")
            (:gentemp ?next-goal "progress")
            (:foreach ?ignored-correspondence ?ignored-correspondences
                      (:unstore (eci-ignore ?ignored-correspondence) scene))
            (:store (mapping-against ?plan ?desired-mapping) scene)
            (:store (mapping-against ?plan ?best-sat-mapping) scene)
            (:store (satisfied-mapping-against-plan ?best-sat ?plan))
            (:store (desired-mapping-against-plan ?desired-mapping ?plan))
            (:store (projected-state ?best-sat-mapping ?best-sat-context))
            (:store (projected-state ?desired-mapping ?desired-context))
            (:store (actual-state ?best-sat-mapping scene))
            (:store (actual-state ?desired-mapping scene))
            (:store (inference-context ?desired-mapping ?inf-context))
            ;; Store the inferences
            (:store-all ?infs ?inf-context)
            ;; set up the todo-context to inherit from the scene and the inferences.
            (:store (:sub-context scene ?todo-context))
            (:store (:sub-context ?inf-context ?todo-context))
            ;; ECI inference.
            (:explain-transition scene ?todo-context scene ?trans-context)
            ;; Store the action selection.
            (:store (isa ?trans-context action-selection))
            (:store (from-state ?trans-context scene))
            (:store (to-state ?trans-context ?desired-context))
            (:dbug "We've satisfied" ?best-sat-context)
            (:dbug "...but can achieve" ?desired-context "with"
                   ?inf-context "described in" ?trans-context)
            ;; Store the inf and trans contexts in the action.
            (:store (inf-context ?action ?inf-context))
            (:store (trans-context ?action ?trans-context))

            (:note "Oriented to plan context" ?plan))
 :result success)

;; Let's have a fallback.
(kbop:method
 :matches ((orient-to-plan ?goal-id ?action))
 :priority -1
 :on-ready ((:note "Unable to orient"))
 :result success)

;;; ------------------------------------------------------------
;;; Propose or just do it?

;;; The default behavior keeps TRIPS in the loop. We propose the
;;; action as a goal. TRIPS turns this into a generate message and
;;; then waits for the user to accept the goal.
;;;
;;; Alternatively, if the user has told us to just finish it, we can
;;; just take the action immediately, without round-tripping through
;;; TRIPS at every step. This is more hackish, but really nice for
;;; demos.
;;;

(kbop:method
 :matches ((what-next-for-action ?goal ?reply-id ?action))
 :pre ((:uninferrable (just-do-it ?goal YES))
       (:uninferrable (have-achieved-the-envisionment ?goal ?envisionment ?plan)))
 :on-ready ((:note "PROPOSE action" ?action)
            (:propose-subgoal ?goal ?reply-id ?action
                              (perform-action ?action))
            (:consume-world-changes ignored))
 :result success)

(kbop:method
 :matches ((what-next-for-action ?goal ?reply-id ?action))
 :pre ((:uninferrable (just-do-it ?goal YES))
       (have-achieved-the-envisionment ?goal ?envisionment ?plan))
 :on-ready ((:subgoal (report-plan-achieved ?plan ?goal ?reply-id))))

(kbop:method
 :matches ((what-next-for-action ?goal ?reply-id ?action))
 :pre ((just-do-it ?goal YES))
 :on-ready ((:note "JUST DOING action" ?action)
            (:consume-world-changes ignored)
            (:subgoal (perform-ecis ?goal ?action ?reply-id))
            ;; No... don't report the outcome... it'll mark the
            ;; top-level goal DONE, which it (probably) isn't!
            ;; (:subgoal (report-action-outcome ?goal ?action ?reply-id))
            ;;
            ;; But, we want to keep going. So, add a subgoal. Let the
            ;; tree get tall until the thing is built.
            (:subgoal (maybe-keep-going ?goal ?action ?reply-id))))

;; Ran into a problem.
(kbop:method
 :matches ((maybe-keep-going ?goal ?action ?reply-id))
 :pre ((action-failure ?action ?failure))
 :on-ready ((:note "stop, we failed" ?failure)
            (:store (done-msg ?goal ?failure)) ; "We ran into a problem."))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::done))))
 :result success)

;; No problem, but more to do.
(kbop:method
 :matches ((maybe-keep-going ?goal ?prev-action ?reply-id))
 :pre ((:uninferrable (action-failure ?prev-action ?failure))
       (:uninferrable (have-achieved-the-envisionment ?goal ?envisionment ?plan)))
 :on-ready ((:note "Take another step")
            (:gentemp ?action "ACTION-")
            (:subgoal (orient-to-plan ?goal ?action))
            (:subgoal (what-next-for-action ?goal ?reply-id ?action)))
 :result success)

;;; If we don't have anything left to do, call this good and report
;;; done.
(kbop:method
 :matches ((maybe-keep-going ?goal ?prev-action ?reply-id))
 :pre ((:uninferrable (action-failure ?prev-action ?failure))
       (have-achieved-the-envisionment ?goal ?envisionment ?plan))
 :on-ready ((:subgoal (report-plan-achieved ?plan ?goal ?reply-id))))

(kbop:method
 :matches ((report-plan-achieved ?plan ?goal ?reply-id))
 :on-ready ((:note "Plan achieved:" ?plan)
            (:store (done-msg ?goal "Great! We built it."))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::done))))
 :result success)


;;; ------------------------------------------------------------
;;; Recognizing the user's desire to just finish it.

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((what ?goal ?what)
       (instance-of ?what ONT::COMPLETE))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal ACCEPTABLE)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((what ?goal ?what)
       (instance-of ?what ONT::COMPLETE)
       (:uninferrable (find-create-goal ?goal ?create-goal)))
 :on-ready ((:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON NO-CREATE-GOAL))))
 :result success)

;;; Here we use a subgoal to propagate the actor-for setting. If the
;;; actor is known, that'll be the new actor moving forward. If not
;;; known, we'll finish (uninterrupted) with the current actor.
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((what ?goal ?what)
       (instance-of ?what ONT::COMPLETE)
       (find-create-goal ?goal ?create-goal))
 :on-ready ((:store (just-do-it ?create-goal YES))
            (:subgoal (propagate-actor ?goal ?create-goal ?reply-id))))

(kbop:method
 :matches ((propagate-actor ?goal ?create-goal ?reply-id))
 :pre ((actor-for ?goal ?actor))
 :on-ready ((:note ?actor)
            (:unstore (actor-for ?create-goal ?any-actor))
            (:store (actor-for ?create-goal ?actor))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::done))))
 :result success)

(kbop:method
 :matches ((propagate-actor ?goal ?create-goal ?reply-id))
 :pre ((:uninferrable (actor-for ?goal ?actor)))
 :on-ready ((:note "no actor")
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::done))))
 :result success)


;; ------------------------------------------------------------
;; Performing actions and reporting results

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((action-for-goal ?goal ?action))
 :on-ready ((:subgoal (perform-ecis ?goal ?action ?reply-id))
            (:subgoal (report-action-outcome ?goal ?action ?reply-id)))
 )

;;; If we are asked WHAT-NEXT and are waiting for the user, indicate
;;; that to the CPSA. Reset the waiting-for-user sym so that we will
;;; only do this once per exec.
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :priority 1
 :pre ((action-for-goal ?goal ?action)
       (waiting-for-user ?action ?waiting-sym))
 :on-ready ((:unstore (waiting-for-user ?action ?any))
            (:gensym ?waiting-sym ("WAITING-" ?action))
            (:store (waiting-for-user ?action ?waiting-sym))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::waiting-for-user)))))

(kbop:method
 :matches ((perform-ecis ?goal ?action ?reply-id))
 :pre ((get-valid-actor ?goal ?actor ?source))
 :on-ready ((:subgoal (record-last-figures ?action))
            (:subgoal (perform-eci-action ?action ?actor ?source))))

;; Here we record the figure for hte last action. We use this as a
;; prefered ground if none is specified in a subsequent utterance.
(kbop:method
 :matches ((record-last-figures ?action))
 :pre ((get-figures-for-action ?action ?figures))
 :on-ready ((:unstore (prev-figure ?any-action ?any-figure))
            (:foreach ?fig ?figures
                      (:store (prev-figure ?action ?fig))))
 :result success)

;; If we can't figure out the figure(s), clear any other ones.
(kbop:method
 :matches ((record-last-figures ?action))
 :pre ((:uninferrable (get-figures-for-action ?action ?figures)))
 :on-ready ((:unstore (prev-figure ?any-action ?any-figure)))
 :result success)

;; We are supposed to act.
(kbop:method
 :matches ((perform-eci-action ?action ont::sys ?source))
 :pre ((inf-context ?action ?inf-ctx)
       (trans-context ?action ?trans-ctx))
 :on-ready ((:take-action ?action ?inf-ctx ?trans-ctx)
            (:subgoal (observe-action ?action))
            (:note "system acts")))

;; The user is supposed to act. Here we just wait for it, or recognize
;; that it already happened.
(kbop:method
 :matches ((perform-eci-action ?action ont::user ?source))
 :on-ready ((:subgoal (observe-action ?action))
            (:gensym ?waiting-sym ("WAITING-" ?action))
            (:store (waiting-for-user ?action ?waiting-sym))
            (:note "wait for user to act")))

(kbop:method
 :matches ((observe-action ?action))
 :pre ((action-failure ?action ?failure))
 :on-ready ((:note "failure" ?failure))
 :result success)

(kbop:method
 :matches ((observe-action ?action))
 :pre ((:uninferrable (action-failure ?action ?failure))
       (:uninferrable (world-change-event ?event-id ?action))
       (world-change-event ?event-id new))
 :on-ready (;; Consume all the world change events, marking them as
            ;; part of this action.
            (:consume-world-changes ?action)
            (:subgoal (update-last-action ?action))
            (:note "world changed"))
 :result success)

(kbop:method
 :matches ((update-last-action ?action))
 :pre ((find-most-recent-action ?most-recent-action))
 :on-ready ((:store (previous-action ?action ?most-recent-action)))
 :result success)

(kbop:method
 :matches ((update-last-action ?action))
 :pre ((:uninferrable
        (find-most-recent-action ?most-recent-action)))
 :on-ready ((:store (previous-action ?action NONE)))
 :result success)

;; [jrye:20170125.0931CST] After discussing with Scott on IM, what we
;; want is something like this:
;;
;; ( : context-intersection scene ?inf-context ?intersection)
;; and ( : context-difference ?inf-context scene ?unresolved-inferences)
;; (FWIW, the context-intersection would be symmetric over the first
;; two args, so they could be flipped) so, forget the "diff" bit.
;;
;; let us assume that 'scene is where all the current world facts
;; live.  and that you've already bound ?inf-context to a context where
;; the inferences were from last localization.
;;
;; invoking context-intersection binds the ?intersection to
;; (set-fn (on b1 grd))
;; and invoking context-difference binds the ?unresolved-inferences to
;; (set-fn (touching b1 b2))
;;
;; if ( : nonempty ?inferences), then OMG, progress!
;; if ( : nonempty ?unresolved-inferences), then we have stuff to do still
;;
;; The thing is, we need to make this assessment when the world
;; changes. What tells us that?
(kbop:method
 :matches ((report-action-outcome ?goal ?action ?reply-id))
 :pre ((action-failure ?action ?failure))
 :on-ready ((:note "action failed:" ?failure)
            (:unstore (waiting-for-user ?action ?any))
            (:store (done-msg ?goal ?failure)) ; "Unable to perform the action"))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
 :result success)

(kbop:method
 :matches ((report-action-outcome ?goal ?action ?reply-id))
 :pre ((world-change-event ?val ?action)
       (inf-context ?action ?inf-context)
       (:context-intersection ?progress-infs ?inf-context scene)
       (:nonempty ?progress-infs))
 :on-ready ((:note "world changed, progress")
            (:unstore (waiting-for-user ?action ?any))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
 :result success)

(kbop:method
 :matches ((report-action-outcome ?goal ?action ?reply-id))
 :pre ((world-change-event ?val ?action)
       (inf-context ?action ?inf-context)
       (:context-intersection ?progress-infs ?inf-context scene)
       (:empty ?progress-infs))
 :on-ready ((:note "world changed, no progress")
            (:unstore (waiting-for-user ?action ?any))
            (:store (done-msg ?goal "That wasn't what we intended."))
            ;; [jrye:20170127.1439CST] By reporting FAILURE, we stop
            ;; the whole system dead. If we report DONE, the CPSA will
            ;; come back and ask for more actions and we can
            ;; gracefully accept actions from an uncooperative user.
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
                                    ;; (FAILURE :what ?goal))))
 :result success)


;;; ------------------------------------------------------------
;;; Notice when we have achieved the plan.
(:in-context collab-context)

(<< (have-achieved-the-envisionment ?goal ?envisionment ?plan)
    (envisionment ?goal ?envisionment)
    (plan-for ?envisionment ?plan)
    (:plan-localize scene ?plan ?best-sat-mapping ?better-unsats)
    ;; (:mapping-target-context ?best-sat-mapping ?best-sat-context)
    (:empty ?better-unsats))

;;; ------------------------------------------------------------
;;; Recognize the figure(s) referred to by an action. We'll use
;;; this/these as a ground in a subsequent action if no more specific
;;; ground is specified.
(:in-context collab-context)

(<< (get-figures-for-action ?action ?figures)
    (trans-context ?action ?trans-ctx)
    (:aggregate ?figures ?fig
                (:in ?trans-ctx (theme ?ent ?fig))))
;;; ------------------------------------------------------------
;;; Looking up the most recent action.
(:in-context collab-context)

(<< (find-most-recent-action ?action)
    (previous-action ?action ?previous-action)
    (:uninferrable (previous-action ?newer-action ?action)))
