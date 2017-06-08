;;; ------------------------------------------------------------
;;; Rules that aggregate content for model building.
;;;

(:in-context collab-context)

;; ------------------------------------------------------------
;; Here are horn clauses for identifying goals to build or expand a
;; model.

(<< (is-build-model-goal ?goal)
    (get-goal-type ?goal ?type)
    (:set-member ?type (set-fn ont::create ont::build-model)))

(<< (is-build-model-goal ?goal)
    (kqml-predicate ?goal assertion)
    (get-goal-type ?goal ont::events-in-model))

;; ------------------------------------------------------------
;; Get the id for the create goal. If one exists.

(<< (find-create-model-in-progress-for-goal ?goal ?model)
    (find-create-goal ?goal ?create-goal)
    (affected-result ?create-goal ?model))

(<< (find-model-content-in-progress-for-goal ?goal ?model)
    ;;(find-content-goal ?goal ?content-goal)
    (instance-of ?content-goal ont::events-in-model)
    (query-id ?content-goal ?query)
    (model ?query ?model))

;; Stopping condition, this is a content goal for a model query.
(<< (find-content-goal ?goal ?content-goal)
    (:uninferrable
     (instance-of ?goal ont::events-in-model))
    (find-collab-parent-goal ?goal ?parent-goal)
    (find-content-goal ?parent-goal ?content-goal))

(<< (find-content-goal ?goal ?content-goal)
    (instance-of ?goal ont::events-in-model)
    (:assign ?create-goal ?goal))


;; Stopping condition, this is a create or build-model goal.
(<< (find-create-goal ?goal ?create-goal)
    (get-goal-type ?goal ?type)
    (:set-member ?type (set-fn ONT::CREATE ONT::BUILD-MODEL))
    (:assign ?create-goal ?goal))

;; Otherwise... if we have a parent goal, try them.
(<< (find-create-goal ?goal ?create-goal)
    (:uninferrable
     (get-goal-type ?goal ?type)
     (:set-member ?type (set-fn ONT::CREATE ONT::BUILD-MODEL)))
    (find-collab-parent-goal ?goal ?parent-goal)
    (find-create-goal ?parent-goal ?create-goal))

;; Lookup the events. As of 22 March 2017, these events show up in
;; ASSERTIONs, each of which CONTRIBUTES-TO a goal.
;;
;; An argument could be made that we should actually recurse so that
;; we find sub-sub-...goals. In the meantime, we just grab the events
;; for this goal and any contributing assertions.
;;
(<< (find-new-model-events ?goal ?all-event-ids ?new-event-ids)
    (find-model-events ?goal ?all-event-ids)
    ;; Prior events or an empty set.
    (some (model-event-ids ?goal ?prior-event-ids)
          (:assign ?prior-event-ids (set-fn)))
    ;; Collect all the IDs that were not in the prior list.
    (:aggregate ?new-event-ids ?event-id
                (and (:set-member ?event-id ?all-event-ids)
                     (:uninferrable (:set-member ?event-id ?prior-event-ids)))))

(<< (find-model-events ?goal ?event-ids)
    ;; The immediate events, or an empty set.
    (some (get-immediate-events-for ?goal ?immediate-event-ids)
          (:assign ?immediate-event-ids (set-fn)))
    (:aggregate ?contributing-event-ids ?event-id
                (and (get-contributing-events-for ?goal ?ces)
                     (:set-member ?event-id ?ces)))
    (:union ?event-ids ?immediate-event-ids ?contributing-event-ids))

(<< (get-contributing-events-for ?goal ?event-ids)
    ;; Find the assertion
    (goal ?tg ?goal)
    (kqml-predicate ?tg CONTRIBUTES-TO)
    (as ?assertion-goal ?tg)
    (kqml-predicate ?assertion-goal ASSERTION)
    (get-immediate-events-for ?assertion-goal ?event-ids))

;; This just maps to the events on this exact goal. No wandering
;; around looking.
(<< (get-immediate-events-for ?goal ?event-ids)
    (what ?goal ?what)
    (events ?what ?event-ids))


;; ------------------------------------------------------------
;; Get the model-id for a goal. Walk up the goal hiearchy to find one
;; from a parent. If found, awesome. If not, gentemp one.

;; Stopping condition... we have an ekb-id to bind to.
(<< (find-model-id ?goal ?model-id)
    (model-id ?goal ?model-id))

;; Otherwise... if we have a parent goal, try them.
(<< (find-model-id ?goal ?model-id)
    (:uninferrable (model-id ?goal ?model-id))
    (find-collab-parent-goal ?goal ?parent-goal)
    (find-model-id ?parent-goal ?model-id))

;; Get the model string for a model id.
(<< (find-model-string ?model-id ?model-string)
    (model-id ?ba-query ?model-id)
    (model ?ba-query ?model-string))
;; ------------------------------------------------------------
;; Get the EKB XML from a reply to our query.

(<< (ekb-xml ?term-id ?the-xml)
    (ekb-id ?term-id ?ekb-id)
    (answer ?ekb-id ?answer)
    (result ?answer ?the-xml))
