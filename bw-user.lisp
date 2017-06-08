;;;; Support for user-directed actions.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; EVALUATE and WHAT-NEXT
;;;
;;; For now, report that goals with action-ecis are always ACCEPTABLE.
;;;
;;; Note that as part of the EVALUATE, we could check to see if we can
;;; find the names of the figure and ground -- or whatever is required
;;; for this action. If either of them failed to ground necessary, we
;;; could ask for clarification about them.
;;;
(kbop:method
 :matches ((evaluate ?goal))
 :pre ((action-eci ?goal ?eci))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((action-eci ?goal ?eci))
 :on-ready ((:gentemp ?action "action-")
            ;; FIXME We *might* only want to store this if the action
            ;; was valid.
            ;; (:store (action-for-goal ?goal ?eci))
            (:store (action ?eci ?action))
            (:subgoal (prepare-eci-action ?eci ?action))
            ;; Collect up a result. If it was a failure, report it --
            ;; and fail, so that we won't try to perform anything.
            (:subgoal (handle-action-eci-result ?goal ?eci ?reply-id))
            ;; Perform the ECIs and report the result.
            (:consume-world-changes ignored)
            (:subgoal (perform-ecis ?goal ?action ?reply-id))
            (:subgoal (report-action-outcome ?goal ?action ?reply-id))))


;;; ------------------------------------------------------------
;;; Prepare the action
;;;
;;; Mostly, this means mapping the ECI information to inf- and
;;; trans-contexts.

(kbop:method
 :matches ((prepare-eci-action ?eci ?action))
 :pre ((what ?eci ?what))
 :on-ready (;; Prepare the inf-context.
            (:gentemp ?inf-ctx "cmd-inf-")
            (:store (inf-context ?action ?inf-ctx))

            ;; And the trans-context.
            (:gentemp ?trans-ctx "cmd-trans-")
            (:store (trans-context ?action ?trans-ctx))

            ;; Defer to a populate method which can specialize on ECI
            ;; details.
            (:subgoal (populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))))

(kbop:method
 :matches ((prepare-eci-action ?eci ?action))
 :pre ((:uninferrable (what ?eci ?what)))
 :on-ready ((:note "no what"))
 :result failure)

(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :pre ((:equalp ?what ONT::ADD-INCLUDE)
       (find-previous-what ?prev-what))
 :on-ready ((:note ?what)
            ;; Grab the remaining values.
            (:subgoal (fill-action-result ?eci))
            (:subgoal (fill-action-figure ?eci))
            (:subgoal (fill-action-ground ?eci))
            ;; And recurse.
            (:subgoal (populate-action-contexts ?prev-what ?eci ?inf-ctx ?trans-ctx))))

;; [jrye:20170314.0745CST] I tried to make all of this normalization
;; rules and got very tangled up. I'm implementing it here, but
;; frankly, I'm not sure this is the best way to do this.
(kbop:method
 :matches ((fill-action-result ?eci))
 :pre ((find-action-result ?eci ?val))
 :on-ready ((:note ?val)
            (:unstore (result ?eci ?any))
            (:store (result ?eci ?val)))
 :result success)

(kbop:method
 :matches ((fill-action-result ?eci))
 :pre ((:uninferrable (find-action-result ?eci ?val)))
 :result success)

(kbop:method
 :matches ((fill-action-figure ?eci))
 :pre ((find-action-figure ?eci ?val))
 :on-ready ((:note ?val)
            (:unstore (figure ?eci ?any))
            (:store (figure ?eci ?val)))
 :result success)

(kbop:method
 :matches ((fill-action-figure ?eci))
 :pre ((:uninferrable (find-action-figure ?eci ?val)))
 :result success)

(kbop:method
 :matches ((fill-action-ground ?eci))
 :pre ((find-action-ground ?eci ?val))
 :on-ready ((:note ?val)
            (:unstore (ground ?eci ?any))
            (:store (ground ?eci ?val)))
 :result success)

(kbop:method
 :matches ((fill-action-ground ?eci))
 :pre ((:uninferrable (find-action-ground ?eci ?val)))
 :result success)

;;; These specializations use priorities and a fallback, to ensure
;;; that all cases are covered.
(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :pre ((:equalp ?what ONT::PUT)
       (result ?eci ONT::ON)
       (get-figure-obj ?eci ?figure-obj)
       (get-ground-obj ?eci ?ground-obj))
 :on-ready ((:note ?figure-obj "on" ?ground-obj)
            (:store (on ?figure-obj ?ground-obj) ?inf-ctx)

            (:gentemp ?eci-ent "ent-")
            (:store
             (:props ?eci-ent
                     :composition-of move-relative
                     :theme ?figure-obj
                     :cotheme ?ground-obj
                     :result (predication-fn on-supporting
                                             :theme ?figure-obj
                                             :cotheme ?ground-obj)
                     :pre-state scene
                     :post-state ?inf-ctx
                     :isa move-relative)
             ?trans-ctx)

            (:store (prepare-action-result ?eci OK)))
 :result success)

(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :pre ((:equalp ?what ONT::PUT)
       (result ?eci ONT::ADJACENT)
       (get-figure-obj ?eci ?figure-obj)
       (get-ground-obj ?eci ?ground-obj))
 :on-ready ((:note ?figure-obj "adjacent to" ?ground-obj)
            (:store (touching-horizontal ?figure-obj ?ground-obj) ?inf-ctx)

            (:gentemp ?eci-ent "ent-")
            (:store
             (:props ?eci-ent
                     :composition-of move-relative
                     :theme ?figure-obj
                     :cotheme ?ground-obj
                     :result (predication-fn together-physical
                                             :theme ?figure-obj
                                             :cotheme ?ground-obj)
                     :pre-state scene
                     :post-state ?inf-ctx
                     :isa move-relative)
             ?trans-ctx)

            (:store (prepare-action-result ?eci OK)))
 :result success)

;;; FIXME We should generalize this "put" behavior. The right-of and
;;; left-of versions are very small extensions of adjacent.

(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :pre ((:equalp ?what ONT::PUT)
       (result ?eci ONT::LEFT-OF)
       (get-figure-obj ?eci ?figure-obj)
       (get-ground-obj ?eci ?ground-obj))
 :on-ready ((:note ?figure-obj "adjacent to" ?ground-obj)
            (:store (touching-horizontal ?figure-obj ?ground-obj) ?inf-ctx)
            (:store (x-greater ?ground-obj ?figure-obj) ?inf-ctx)

            (:gentemp ?eci-ent "ent-")
            (:store
             (:props ?eci-ent
                     :composition-of move-relative
                     :theme ?figure-obj
                     :cotheme ?ground-obj
                     :result (predication-fn together-physical
                                             :theme ?figure-obj
                                             :cotheme ?ground-obj)
                     :pre-state scene
                     :post-state ?inf-ctx
                     :isa move-relative)
             ?trans-ctx)

            (:store (prepare-action-result ?eci OK)))
 :result success)

(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :pre ((:equalp ?what ONT::PUT)
       (result ?eci ONT::RIGHT-OF)
       (get-figure-obj ?eci ?figure-obj)
       (get-ground-obj ?eci ?ground-obj))
 :on-ready ((:note ?figure-obj "adjacent to" ?ground-obj)
            (:store (touching-horizontal ?figure-obj ?ground-obj) ?inf-ctx)
            (:store (x-greater ?figure-obj ?ground-obj) ?inf-ctx)

            (:gentemp ?eci-ent "ent-")
            (:store
             (:props ?eci-ent
                     :composition-of move-relative
                     :theme ?figure-obj
                     :cotheme ?ground-obj
                     :result (predication-fn together-physical
                                             :theme ?figure-obj
                                             :cotheme ?ground-obj)
                     :pre-state scene
                     :post-state ?inf-ctx
                     :isa move-relative)
             ?trans-ctx)

            (:store (prepare-action-result ?eci OK)))
 :result success)


(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :priority -1
 :pre ((:equalp ?what ONT::PUT))
 :on-ready ((:note "missing info")
            (:store (prepare-action-result ?eci MISSING-INFORMATION)))
 :result success)

(kbop:method
 :matches ((populate-action-contexts ?what ?eci ?inf-ctx ?trans-ctx))
 :priority -99
 :on-ready ((:note "unable to populate contexts")
            (:store (prepare-action-result ?eci DONT-UNDERSTAND-ACTION)))
 :result success)

;;; ------------------------------------------------------------
;;; Lookup and report results

(kbop:method
 :matches ((handle-action-eci-result ?goal ?eci ?reply-id))
 :pre ((determine-action-eci-failure ?eci ?failure))
 :on-ready ((:note "FAILURE" ?failure)
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON ?failure))))
 :result failure)

(kbop:method
 :matches ((handle-action-eci-result ?goal ?eci ?reply-id))
 :pre ((:uninferrable (determine-action-eci-failure ?eci ?failure)))
 :on-ready ((:note "OK")
            ;; (:report-status ?goal ?reply-id
            ;;                 (REPORT :content
            ;;                         (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done)))
            )
 :result success)

;;; ------------------------------------------------------------
;;; Lookup for results
;;;
(:in-context collab-context)

(<< (determine-action-eci-failure ?eci ?failure)
    (prepare-action-result ?eci ?failure)
    (:uninferrable (:equalp ?failure OK)))

;;; ------------------------------------------------------------
;;; Choose figure and ground objects
;;;
(:in-context collab-context)

(<< (get-figure-obj ?eci ?obj)
    (figure ?eci ?id)
    (get-allowed-scene-objs ?id ?allowed-objs)
    (get-preferred-figure-objs ?id ?preferred-objs)
    (choose-preferred-obj ?allowed-objs ?preferred-objs ?obj))

(<< (get-ground-obj ?eci ?obj)
    (ground ?eci ?id)
    (get-allowed-scene-objs ?id ?allowed-objs)
    (get-preferred-ground-objs ?id ?preferred-objs)
    (choose-preferred-obj ?allowed-objs ?preferred-objs ?obj))


;; Get the allowed scene objects directly from the obj, or from the
;; constraints. Or, if none directly and no constraints, any named
;; object should do.
(<< (get-allowed-scene-objs ?id ?allowed-objs)
    (scene-objs ?id ?allowed-objs))

(<< (get-allowed-scene-objs ?id ?allowed-objs)
    (:uninferrable (scene-objs ?id ?allowed-objs))
    (constraints ?id ?cid)
    (get-allowed-scene-objs ?cid ?allowed-objs))

(<< (get-allowed-scene-objs ?id ?allowed-objs)
    (:uninferrable (scene-objs ?id ?allowed-objs))
    (:uninferrable (constraints ?id ?cid))
    (:aggregate ?allowed-objs ?a
                (:in scene (name ?a ?name0))))

;; If the id refers to "it", try to map to something that could be
;; "it". Otherwise, get something reasonable in the scene -- take a
;; figure from the shelf or a choose a ground already in the scene
;; someplace.
;;
;; The idea is that if we *actually* moved something in the scene,
;; that is more current or meaningful than what we (or the user) said
;; to move. And, whatever we talked about is move meaningful than
;; anything old thing in the scene.

(<< (get-preferred-figure-objs ?id ?preferred-objs)
    (get-preferred-objs-for-it ?id ?preferred-objs))

(<< (get-preferred-figure-objs ?id ?preferred-objs)
    (:uninferrable (get-preferred-objs-for-it ?id ?preferred-objs))
    ;; Prefer shelved figures.
    (:aggregate ?preferred-objs ?a
                (:in scene (and (name ?a ?name)
                                (isa ?a shelved)))))


(<< (get-preferred-ground-objs ?id ?preferred-objs)
    (get-preferred-objs-for-it ?id ?preferred-objs))

;; (<< (get-preferred-ground-objs ?id ?preferred-objs)
;;     (:uninferrable (:in scene (isa ?any-obj moved)))
;;     (:aggregate ?preferred-objs ?fig
;;                 (prev-figure ?any-action ?fig)))

(<< (get-preferred-ground-objs ?id ?preferred-objs)
    ;; (:uninferrable (:in scene (isa ?any-obj moved)))
    ;; (:uninferrable (prev-figure ?any-action ?fig))
    (:uninferrable (get-preferred-objs-for-it ?id ?preferred-objs))
    (:aggregate ?preferred-objs ?a
                (:in scene (and (name ?a ?name)
                                (:uninferrable (isa ?a shelved))))))

;; If the ECI's figure or ground refers to "it", we take it to mean
;; the last thing we moved, or the previous action's figure. This way,
;; when the user says "put b12 on the table", "push it next to b10",
;; the "it" maps to something that makes sense to the user.
;;
;; FIXME Notice that if the figure/ground id is a referential-sem with
;; a coref to a previously known object, we would *love* to respond
;; with whatever obj we chose before. We should update the
;; report-action- stuff to record the object that actually moved as a
;; binding on the unnamed obj from TRIPS so that we can resolve it
;; properly here instead of guessing heuristically.
;;
(<< (get-preferred-objs-for-it ?id ?preferred-objs)
    (instance-of ?id ont::referential-sem)
    (:aggregate ?preferred-objs ?obj
                (:in scene (isa ?obj moved))))

(<< (get-preferred-objs-for-it ?id ?preferred-objs)
    (instance-of ?id ont::referential-sem)
    (:aggregate ?moved-objs ?obj
                (:in scene (isa ?obj moved)))
    (:empty ?moved-objs)
    (:aggregate ?preferred-objs ?fig
                (prev-figure ?any-action ?fig)))

;; One or more of the allowed objects is in the preferred list. So
;; choose from that intersection.
(<< (choose-preferred-obj ?allowed-objs ?preferred-objs ?obj)
    (:intersection ?objs ?allowed-objs ?preferred-objs)
    (:uninferrable (:empty ?objs))
    (:first-elt-in ?objs ?obj))

;; None of the allowed objs are preferred, just pick any allowed obj.
(<< (choose-preferred-obj ?allowed-objs ?preferred-objs ?obj)
    (:intersection ?objs ?allowed-objs ?preferred-objs)
    (:empty ?objs)
    (:first-elt-in ?allowed-objs ?obj))

;;; ------------------------------------------------------------
;;; Look up values for action.
;;;
(:in-context collab-context)

(<< (find-previous-what ?what)
    (find-most-recent-action ?prev-action)
    (find-what-in-action ?prev-action ?what))

;; Stopping condition.
(<< (find-what-in-action ?action ?what)
    (action ?eci ?action)
    (what ?eci ?what)
    (:uninferrable (:equalp ?what ONT::ADD-INCLUDE)))

;; Recurse.
(<< (find-what-in-action ?action ?prev-what)
    (action ?eci ?action)
    (what ?eci ?what)
    (:equalp ?what ONT::ADD-INCLUDE)
    (previous-action ?action ?prev-action)
    (find-what-in-action ?prev-action ?prev-what))

(<< (find-action-result ?eci ?val)
    (find-most-recent-action ?prev-action)
    (action ?prev-eci ?prev-action)
    (some (result ?eci ?val)
          (result ?prev-eci ?val)))

(<< (find-action-figure ?eci ?val)
    (find-most-recent-action ?prev-action)
    (action ?prev-eci ?prev-action)
    (some (figure ?eci ?val)
          (figure ?prev-eci ?val)))

(<< (find-action-ground ?eci ?val)
    (find-most-recent-action ?prev-action)
    (action ?prev-eci ?prev-action)
    (some (ground ?eci ?val)
          (figure ?prev-eci ?val)))

