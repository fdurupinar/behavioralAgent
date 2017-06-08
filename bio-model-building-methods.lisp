;;; ------------------------------------------------------------
;;; Bio methods that define the goal hierarchy and executive
;;; behavior for the SPG w/r/t handling bioagents.
;;;
(:in-context exec-methods)

;; --------------------------------
;; High-level CPSA goal
;; --------------------------------

;; CREATE MODEL

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-build-model-goal ?goal)
       (find-create-goal ?goal ?create-goal)
       ;; [jrye:20161214.1120CST] It's acceptable if this is a goal to
       ;; create a model. We used to look up the tree, but that was a
       ;; problem because we were accepting subgoals that were
       ;; nonsense.
       (:same ?goal ?create-goal))
 :on-ready ((:note "ACCEPTABLE, is a create goal")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-build-model-goal ?goal)
       (find-create-goal ?goal ?create-goal))
 :on-ready ((:note "ACCEPTABLE, have model events")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

;; If the goal has events, sweet. Actually do the model building work.
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-build-model-goal ?goal)
       (find-create-goal ?goal ?create-goal)
       ;; If the goal has new events...
       (find-new-model-events ?goal ?all-event-ids ?new-event-ids)
       (:nonempty ?new-event-ids))
 :on-ready (;; Make sure the goal reflects the complete list of events.
            (:unstore (model-event-ids ?goal ?any-ids))
            (:store (model-event-ids ?goal ?all-event-ids))

            ;; Now continue with formatting the XML and making the
            ;; request.
            (:subgoal (retrieve-ekb-xml ?new-event-ids ?goal))

            (:subgoal (build-or-extend-model ?goal))

            ;; We don't want to say we're done, because the user may
            ;; want to add stuff to the model. So, we'll just say
            ;; we're waiting for the user.
            ;;
            ;; Notice that we *probably* want to *say* something to
            ;; the user about what we did (or didn't) do here. But as
            ;; of 22 March 2017, we have no way to tell the CPSA this.
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::waiting-for-user)))))

;; Otherwise, just reply back that we are waiting for the user.
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :priority -1
 :pre ((is-build-model-goal ?goal)
       (find-create-goal ?goal ?create-goal))
 :on-ready ((:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::waiting-for-user))))
 :result success)

;; ------------------------------
;; Prepare the message.

;; If we don't have a model, BUILD one.
(kbop:method
 :matches ((build-or-extend-model ?main-goal))
 :priority 1
 :pre (;; Only proceed once the EKB XML is ready.
       (ekb-xml ?main-goal ?the-xml)
       ;; Get the parent create goal. If one doesn't exist, don't
       ;; build a model.
       (find-create-goal ?main-goal ?create-goal)
       ;; But don't do it if we already send a message.
       (:uninferrable (model-query-id ?main-goal ?mqid)))
 :on-ready ((:gentemp ?query-id "build-model-")
            (:store (model-query-id ?main-goal ?query-id))
            (:store (query ?query-id (build-model :description ?the-xml)))
            (:note "BUILD-MODEL")
            (:store (model-build-task ?query-id build))
            (:subgoal (ask-bioagents ?query-id ?main-goal))
            (:subgoal (record-model ?query-id ?create-goal))
            (:subgoal (notify-user-of-model-change ?main-goal ?query-id))
            (:subgoal (update-model-diagram ?main-goal ?query-id))
            ))

;; If we do have a model, EXPAND it.
(kbop:method
 :matches ((build-or-extend-model ?main-goal))
 :priority 2
 :pre (;; Only proceed once the EKB XML is ready.
       (ekb-xml ?main-goal ?the-xml)
       ;; Get the parent create goal. If one doesn't exist, don't
       ;; expand a model.
       (find-create-goal ?main-goal ?create-goal)
       ;; If there was a model ID on the create goal.
       (find-model-id ?main-goal ?model-id)
       ;; But don't do it if we already send a message.
       (:uninferrable (model-query-id ?main-goal ?mqid)))
 :on-ready ((:gentemp ?query-id "expand-model-")
            (:store (model-query-id ?main-goal ?query-id))
            (:store (query ?query-id (expand-model :model-id ?model-id
                                     :description ?the-xml)))
            (:note "EXPAND-MODEL")
            (:store (model-build-task ?query-id expand))
            (:subgoal (ask-bioagents ?query-id ?main-goal))
            (:subgoal (record-model ?query-id ?create-goal))
            (:subgoal (notify-user-of-model-change ?main-goal ?query-id))
            (:subgoal (update-model-diagram ?main-goal ?query-id))
            ))

;; --------------------------------
;; DISPLAY MODEL DIAGRAM
;; --------------------------------

(kbop:method
 :matches ((record-model ?query-id ?create-goal))
 :pre ((answer ?query-id ?answer-id)
       (model-id ?answer-id ?model-id))
 :on-ready ((:note "model id:" ?model-id)
            ;; Need to unstore any previous model id.
            (:unstore (model-id ?create-goal ?other-id))
            (:store (model-id ?create-goal ?model-id)))
 :result success)

(kbop:method
 :matches ((record-model ?query-id ?create-goal))
 :priority -1
 :on-ready ((:note "no model id"))
 :result success)

(kbop:method
 :matches ((update-model-diagram ?main-goal ?query-id))
 :priority 1
 :pre ((answer ?query-id ?answer-id)
       (diagram ?answer-id ?diagram-pathname))
 :on-ready ((:dbug "Gotta display a diagram" ?diagram-pathname)
            (:publish ?diagram-pathname)
            ))

;; FIXME We should probably report some kind of error back to the
;; CPSA. But maybe that needs to happen at a higher level?
(kbop:method
 :matches ((update-model-diagram ?main-goal ?query-id))
 :priority -1
 :pre ((answer ?query-id ?answer-id)
       (:uninferrable (diagram ?answer-id ?diagram-pathname)))
 :on-ready ((:say "I wasn't able to make a diagram to show you."))
 :result success)

;; Whenever model-new is available, we report the update
(kbop:method
 :matches ((notify-user-of-model-change ?main-goal ?query-id))
 :priority 2
 :pre ((answer ?query-id ?answer-id)
       (model-new ?answer-id ?model))
 :on-ready ((:gentemp ?nlg-id "nlg-")
            (:subgoal (get-bio-nlg-text ?main-goal ?model ?nlg-id))
            (:subgoal (tell-user-model-changed ?nlg-id))))

;; This is the case where we tried a model expansion but there is nothing
;; added to the model
(kbop:method
 :matches ((notify-user-of-model-change ?main-goal ?query-id))
 :priority 1
 :pre ((answer ?query-id ?answer-id)
       (model ?answer-id ?model)
       (model-build-task ?query-id ?task)
       (:same ?task expand))
 :on-ready ((:say "I did not change the model.")))

;; This is the case where a new model has just been built
(kbop:method
 :matches ((notify-user-of-model-change ?main-goal ?query-id))
 :priority 1
 :pre ((answer ?query-id ?answer-id)
       (model ?answer-id ?model)
       (model-build-task ?query-id ?task)
       (:same ?task build))
 :on-ready ((:gentemp ?nlg-id "nlg-")
            (:subgoal (get-bio-nlg-text ?main-goal ?model ?nlg-id))
            (:subgoal (tell-user-model-created ?nlg-id))))


;;(kbop:method
;; :matches ((notify-user-of-model-change ?main-goal ?answer-id))
;; :priority -1
;; :on-ready (;; FIXME We should *not* just blurt stuff out like
            ;; this. But as of 27 March 2017, we have no way to tell
            ;; TRIPS that we want to say something.
;;            (:say "I updated the model diagram."))
;; :result success)

(kbop:method
 :matches ((tell-user-model-changed ?nlg-id))
 :priority 2
 :pre ((answer ?nlg-id ?answer-id)
       (nl ?answer-id ?nl)
       (:uninferrable (:aggregatep ?nl)))
 :on-ready (;; FIXME We should *not* just blurt stuff out like
            ;; this. But as of 27 March 2017, we have no way to tell
            ;; TRIPS that we want to say something.
            (:say "I did not change the model."))
 :result success)

(kbop:method
 :matches ((tell-user-model-changed ?nlg-id))
 :priority 1
 :pre ((answer ?nlg-id ?answer-id)
       (nl ?answer-id ?nl)
       (:cdr ?utterances ?nl)
       (:stormat ?utterance
                 "I added ~{~#[~;~a~;~a and ~a~:;~@{~a~#[~;, and ~:;, ~]~}~]~} to the model."
                 (?utterances)))
 :on-ready (;; FIXME We should *not* just blurt stuff out like
            ;; this. But as of 27 March 2017, we have no way to tell
            ;; TRIPS that we want to say something.
            (:say ?utterance))
 :result success)

(kbop:method
 :matches ((tell-user-model-created ?nlg-id))
 :priority 2
 :pre ((answer ?nlg-id ?answer-id)
       (nl ?answer-id ?nl)
       (:uninferrable (:aggregatep ?nl)))
 :on-ready (;; FIXME We should *not* just blurt stuff out like
            ;; this. But as of 27 March 2017, we have no way to tell
            ;; TRIPS that we want to say something.
            (:say "I did not create a model."))
 :result success)

(kbop:method
 :matches ((tell-user-model-created ?nlg-id))
 :priority 1
 :pre ((answer ?nlg-id ?answer-id)
       (nl ?answer-id ?nl)
       (:cdr ?utterances ?nl)
       (:stormat ?utterance
                 "I created a model where ~{~#[~;~a~;~a and ~a~:;~@{~a~#[~;, and ~:;, ~]~}~]~}."
                 (?utterances)))
 :on-ready (;; FIXME We should *not* just blurt stuff out like
            ;; this. But as of 27 March 2017, we have no way to tell
            ;; TRIPS that we want to say something.
            (:say ?utterance))
 :result success)

;; --------------------------------
;; Undo (for models)
;; --------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((get-goal-type ?goal ont::undo)
       (find-collab-parent-goal ?goal ?parent-goal)
       (is-build-model-goal ?parent-goal)
       (find-create-goal ?goal ?create-goal))
 :on-ready ((:note "ACCEPTABLE, undo of" ?parent-goal)
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((get-goal-type ?goal ont::undo)
       (find-collab-parent-goal ?goal ?parent-goal)
       (is-build-model-goal ?parent-goal)
       (find-create-goal ?goal ?create-goal)
       ;; Don't make multiple queries.
       (:uninferrable (model-query-id ?goal ?mqid)))
 :on-ready ((:gentemp ?query-id "undo-model-")
            (:store (model-query-id ?goal ?query-id))
            (:store (query ?query-id (model-undo)))
            (:note "UNDO-MODEL")
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (record-model ?query-id ?create-goal))
            (:subgoal (update-model-diagram ?goal ?query-id))))

