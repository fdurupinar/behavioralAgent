;;;; Rules for transforming TRIPS logical forms into normalized
;;;; (ECI-based) facts.
;;;;
(:unstore-context normalization-rules)
(:in-context normalization-rules)

;;; ------------------------------------------------------------
;;; Identifying ECIs.

;;; FIXME We would like a nice mechanism to create ECI IDs and store
;;; references just in time. This way we would only make ECI IDs when
;;; we actually recognized something.
;;;
;;; I tried with a couple horn clauses, but we cannot store the
;;; reference in a horn clause. So, for now, I'm just gensym'ing IDs.

;;; ------------------------------
;;; Affected result ECIs

(kbop:rule
 :lhs ((affected-result ?id ?obj-id)
       (:uninferrable (eci ?obj-id ?eci-id))
       (:gensym ?eci-id ("ECI-FOR-" ?obj-id)))
 :rhs ((eci ?obj-id ?eci-id)))

;; And propagate the ECI to the goal.
(kbop:rule
 :lhs ((what ?goal ?what)
       (affected-result ?what ?rid)
       (eci ?rid ?eci))
 :rhs ((affected-result-eci ?goal ?eci)))

;;; ------------------------------
;;; Action ECIs

(kbop:rule
 :lhs ((what ?goal ?what)
       (instance-of ?what ?type)
       (:set-member ?type (set-fn ONT::PUT ONT::MOVE ONT::ADD-INCLUDE))
       (:gensym ?eci-id ("ECI-FOR-" ?what)))
 :rhs ((eci ?what ?eci-id)))

;; And propagate the ECI to the goal.
(kbop:rule
 :lhs ((what ?goal ?what)
       (eci ?what ?eci))
 :rhs ((action-eci ?goal ?eci)))

;;; ------------------------------------------------------------
;;; Structures
;;;
;;; Here we have rules to recognize various structure specifications.

(kbop:rule
 :lhs ((instance-of ?obj-id ONT::STAIRS)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id staircase)))

(kbop:rule
 :lhs (;; (instance-of ?obj-id ONT::SET)
       (element-type ?obj-id ONT::STEP)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id staircase)))

;; "build a stack"
(kbop:rule
 :lhs ((instance-of ?obj-id ONT::COLUMN-FORMATION)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id stack)))

;; "build a column"
(kbop:rule
 :lhs ((lex ?obj-id W::COLUMN)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id stack)))

;; "build a tower"
(kbop:rule
 :lhs ((instance-of ?obj-id ONT::TOWER)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id stack)))

;; "build a row"
(kbop:rule
 :lhs ((instance-of ?obj-id ONT::ROW-FORMATION)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id row)))

;; "build a line"
(kbop:rule
 :lhs ((instance-of ?obj-id ONT::LINEAR-GROUPING)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id row)))

;; "make a 5 block line
(kbop:rule
 :lhs ((instance-of ?obj-id ONT::graphic-symbol)
       (lex ?obj-id W::LINE)
       (eci ?obj-id ?eci-id))
 :rhs ((type ?eci-id row)))


;;; ------------------------------------------------------------
;;; Size

;; "five step stairs"
(kbop:rule
 :lhs ((mod ?obj-id ?mid)
       (ground ?mid ?gid)
       (amount ?gid ?size)
       (eci ?obj-id ?eci-id))
 :rhs ((size ?eci-id ?size)))

;; "stairs with five steps"
(kbop:rule
 :lhs ((affected-result ?aid ?obj-id)
       (mod ?aid ?mid)
       (ground ?mid ?gid)
       (size ?gid ?sid)
       (value ?sid ?size)
       (eci ?obj-id ?eci-id))
 :rhs ((size ?eci-id ?size)))

;; "column of 4 blocks"
(kbop:rule
 :lhs ((affected-result ?aid ?obj-id)
       (figure ?obj-id ?fid)
       (size ?fid ?vid)
       (value ?vid ?size)
       (eci ?obj-id ?eci-id))
 :rhs ((size ?eci-id ?size)))

;;; ------------------------------------------------------------
;;; Map actor choices for goals.

(kbop:rule
 :lhs ((kqml-predicate ?eid answer)
       (what ?eid ?wid)
       (instance-of ?wid who)
       (value ?eid ?vid)
       (refers-to ?vid ?actor)
       (to ?eid ?qid)
       (pertains-to ?qid ?goal)
       ;; Make sure the actor is valid.
       (is-valid-actor ?actor))
 :rhs ((actor-for ?goal ?actor)))

(kbop:rule
 :lhs ((what ?goal ?wid)
       (agent ?wid ?aid)
       (refers-to ?aid ?actor)
       ;; Make sure the actor is valid.
       (is-valid-actor ?actor))
 :rhs ((actor-for ?goal ?actor)))

;;; ------------------------------------------------------------
;;; Map the color constraints.

(kbop:rule
 :lhs ((scene-color ?id ?color)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (color ?constraint-id ?color)))

;; Map the ONT:: colors to the JavaScript scene colors.
(kbop:rule
 :lhs ((instance-of ?id ONT::RED))
 :rhs ((scene-color ?id color-255-0-0)))

(kbop:rule
 :lhs ((instance-of ?id ONT::GREEN))
 :rhs ((scene-color ?id color-0-255-0)))

;; "Use green for the right two blocks" resulted in color-scale. Fall
;; back to the lex.
(kbop:rule
 :lhs ((lex ?id W::GREEN))
 :rhs ((scene-color ?id color-0-255-0)))

(kbop:rule
 :lhs ((instance-of ?id ONT::ORANGE))
 :rhs ((scene-color ?id color-255-102-0)))

;; "Use orange on the bottom" resulted in the fruit.
(kbop:rule
 :lhs ((instance-of ?id ONT::FRUIT)
       (lex ?id W::ORANGE))
 :rhs ((scene-color ?id color-255-102-0)))

(kbop:rule
 :lhs ((instance-of ?id ONT::BLUE))
 :rhs ((scene-color ?id color-0-0-255)))

;; ------------------------------------------------------------
;; Map the location constraints to the constraint place.

(kbop:rule
 :lhs ((get-constrained-location-val ?id ?loc)
       (:set-member ?loc (set-fn ONT::TOP-LOCATION-VAL ONT::TOP-LOCATION))
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id top-of)))

(kbop:rule
 :lhs ((get-constrained-location-val ?id ?loc)
       (:set-member ?loc (set-fn ONT::BOTTOM-LOCATION-VAL ONT::BOTTOM-LOCATION))
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id bottom-of)))

(kbop:rule
 :lhs ((get-constrained-location-val ?id ONT::MIDDLE-LOCATION-VAL)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id middle-of)))

(kbop:rule
 :lhs ((get-constrained-location-val ?id ONT::LEFT ONT::LEFT-LOC)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id left-of)))

(kbop:rule
 :lhs ((get-constrained-location-val ?id ?type)
       (:set-member ?type (set-fn ONT::RIGHT ONT::RIGHT-LOC ONT::CORRECTNESS-VAL ONT::SOCIAL-CONTRACT))
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id right-of)))

(kbop:rule
 :lhs ((get-constrained-location-val ?id ONT::ENDPOINT)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id ends-of)))

(kbop:rule
 :lhs ((get-constrained-location-val ?id ?type)
       (:set-member ?type (set-fn ONT::REMAINING-PART ONT::PART-WHOLE-VAL))
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id rest-of)))

;; If we say: "the top block(s)":
(<< (get-constrained-location-val ?id ?loc)
    (instance-of ?id ?loc))

;; If we say: "the tops":
(<< (get-constrained-location-val ?id ?loc)
    (instance-of ?id ont::set)
    (element-type ?id ?loc))

;; Recognize <n>th.
(kbop:rule
 :lhs ((instance-of ?id ONT::BLOCK)
       (ordinal ?id ?n)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id ?n)))

;; First/last <N> blocks.
(kbop:rule
 :lhs ((instance-of ?id ONT::SET)
       (element-type ?id ONT::BLOCK)
       (ordinal ?id 1)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id first-of)))

;; Plural last/final.
(kbop:rule
 :lhs ((instance-of ?id ONT::SET)
       (element-type ?id ONT::BLOCK)
       (mod ?id ?mid)
       (lex ?mid ?lex)
       (:set-member ?lex (set-fn W::LAST W::FINAL))
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id last-of)))

;; Singular last/final.
(kbop:rule
 :lhs ((instance-of ?id ONT::BLOCK)
       (mod ?id ?mid)
       (lex ?mid ?lex)
       (:set-member ?lex (set-fn W::LAST W::FINAL))
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (location ?constraint-id last-of)))


;;; ------------------------------------------------------------
;;; Map the type (isa) constraints.

(kbop:rule
 :lhs ((element-type ?id ONT::BLOCK)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (isa ?constraint-id block)))

(kbop:rule
 :lhs ((instance-of ?id ONT::BLOCK)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (isa ?constraint-id block)))

;;; ------------------------------------------------------------
;;; Map the quantity constraints

(kbop:rule
 :lhs ((instance-of ?id ONT::NUMBER)
       (value ?id ?quantity)
       (:gensym ?constraint-id ("CONSTRAINT-FOR-" ?id)))
 :rhs ((constraint ?id ?constraint-id)
       (quantity ?constraint-id ?quantity)))

;;; ------------------------------------------------------------
;;; Propagating constraints
;;;
;;; These reflect user-specified constraints on a goal. They
;;; will be applied to an envisionment or re-envisionment. We store
;;; them on the make/build object itself so that they can easily be
;;; found when executing the goal (i.e., without searching over the
;;; logical structure to find them).

;; Assemble constraints from further down the semantic tree.
;;

;; We start from the actual goal itself.
(kbop:rule
 :lhs ((what ?id ?wid)
       (get-constraint-id ?wid ?cid)
       (:gensym ?constraints-id ("CONSTRAINTS-FOR-" ?id)))
 :rhs ((constraints ?id ?constraints-id)
       (constraint ?constraints-id ?cid)))

;; We also start from the individual blocks.  Typically "a block" or
;; "the block" or even "b1" becomes instance-of ont::block. When we say
;; "... on the red one" it becomes an ont::referential-sem with a
;; coref or equals to an instance that is a block. Here we try to
;; accept any of those starts.
(kbop:rule
 :lhs ((some (instance-of ?id ont::block)
             (and (instance-of ?rid ont::referential-sem)
                  (coref ?rid ?id)
                  (instance-of ?id ont::block))
             (and (instance-of ?rid ont::referential-sem)
                  (equals ?rid ?id)
                  (instance-of ?id ont::block)))
       (get-constraint-id ?id ?cid)
       (:gensym ?constraints-id ("CONSTRAINTS-FOR-" ?id)))
 :rhs ((constraints ?id ?constraints-id)
       (constraint ?constraints-id ?cid)))

;; Here is some tricky recursion. Walk down the tree to match
;; constraints. The recursion maintains a set of visited IDs to break
;; cycles.
;;
;; This is pretty cool, but leaves a potential problem for later. That
;; is, we lose any ordering information. So when we having a set of
;; constraints indicating that the top block should be green, we don't
;; know if the implication is:
;;
;; if top-block => make it green.
;;    <or>
;; if green => make it a top block.
;;
;; Additionally, we may need to consider revising this if we get
;; multiple constraints; e.g., "Make the top blocks red and the bottom
;; blocks green."
;;
(<< (get-constraint-id ?id ?constraint-id)
    (:bound ?id)
    (get-constraint-id-helper-1 (set-fn) ?id ?constraint-id))

;; Constraint on this ID? Bind to it.
(<< (get-constraint-id-helper-1 ?visited-ids ?id ?constraint-id)
    (constraint ?id ?constraint-id))

;; Haven't visited this yet and has a child? Update the visited list
;; and go there.
(<< (get-constraint-id-helper-1 ?visited-ids ?id ?constraint-id)
    (:bound ?visited-ids)
    (:uninferrable (:set-member ?id ?visited-ids))
    (:union ?newly-visited-ids ?visited-ids (set-fn ?id))
    (get-constraint-id-helper-2 ?newly-visited-ids ?id ?constraint-id))

;; These define the links to follow for recursively searching for
;; constraints.
(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (formal ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (affected ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (affected-result ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (mod ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (figure ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (ground ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (assoc-with ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (size ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (location ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (some (equals ?id ?sub-id)
          (coref ?id ?sub-id))
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

;; This shows up for utterances like:
;; "use green for the right two blocks"
(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (reason ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

;; Shows up when we say:
;; "put a block to the right of..."
(<< (get-constraint-id-helper-2 ?visited-ids ?id ?constraint-id)
    (result ?id ?sub-id)
    (get-constraint-id-helper-1 ?visited-ids ?sub-id ?constraint-id))

;;; ------------------------------------------------------------
;;; Collecting Action ECI info

(kbop:rule
 :lhs ((eci ?id ?eci)
       (instance-of ?id ?type)
       (:set-member ?type (set-fn ONT::PUT ONT::MOVE)))
 :rhs ((what ?eci ONT::PUT)))

(kbop:rule
 :lhs ((eci ?id ?eci)
       (instance-of ?id ?type)
       (:set-member ?type (set-fn ONT::ADD-INCLUDE)))
 :rhs ((what ?eci ONT::ADD-INCLUDE)))

(<< (position-via-result ?id ?type)
    (some
     (result ?id ?rid)
     (transient-result ?id ?rid))
    (or (instance-of ?rid ?type)
        (lex ?rid ?type)))

(<< (position-via-affected ?id ?type)
    (affected ?id ?aid)
    (location ?aid ?lid)
    (instance-of ?lid ?type))

(<< (position-via-result-ground ?id ?type)
    (result ?id ?rid)
    (ground ?rid ?gid)
    (instance-of ?gid ?type))

(<< (position-type ?id ?type)
    (some (position-via-result ?id ?type)
          (position-via-affected ?id ?type)
          (position-via-result-ground ?id ?type)))

;; Accept some types straight out.
(kbop:rule
 :lhs ((eci ?id ?eci)
       (position-type ?id ?type)
       (:set-member ?type (set-fn ONT::ADJACENT)))
 :rhs ((result ?eci ?type)))

;; Accept left-of and right-of.
(kbop:rule
 :lhs ((eci ?id ?eci)
       (position-type ?id ?type)
       (:set-member ?type (set-fn ONT::LEFT-LOC W::LEFT)))
 :rhs ((result ?eci ONT::LEFT-OF)))

(kbop:rule
 :lhs ((eci ?id ?eci)
       (position-type ?id ?type)
       (:set-member ?type (set-fn ONT::RIGHT-LOC W::RIGHT)))
 :rhs ((result ?eci ONT::RIGHT-OF)))

;; Map ONT::ON, ONT::OVER, etc. to a single type.
(kbop:rule
 :lhs ((eci ?id ?eci)
       (position-type ?id ?type)
       (:set-member ?type (set-fn ONT::ON ONT::OVER ONT::POS-AS-OVER)))
 :rhs ((result ?eci ONT::ON)))

;; ------------------------------
;; Map out the figure and ground.

;; These seem unnecessarily specific. And, they have too much
;; structural repetition. We can make it more general later.
;;
(kbop:rule
 :lhs ((eci ?id ?eci)
       (some (result ?id ?rid)
             (transient-result ?id ?rid))
       (figure ?rid ?fid))
 :rhs ((figure ?eci ?fid)))

;; If the user says "add a block", the affected is the thing we're
;; adding. Interpret that as the figure.
(kbop:rule
 :lhs ((eci ?id ?eci)
       (affected ?id ?fid)
       (instance-of ?fid ont::block))
 :rhs ((figure ?eci ?fid)))

;; When we say "put A to the right of B" the ground isn't the ground,
;; it's a right-loc with a figure pointing to the ground. Here we try
;; to recognize it either way.
(kbop:rule
 :lhs ((eci ?id ?eci)
       (some (result ?id ?rid)
             (transient-result ?id ?rid))
       (some (and (ground ?rid ?gid1)
                  (figure ?gid1 ?gid))
             (ground ?rid ?gid)))
 :rhs ((ground ?eci ?gid)))

;; We get these two figure and ground specs by saying something like:
;; put b9 over b8
(kbop:rule
 :lhs ((eci ?id ?eci)
       (affected ?id ?aid)
       (location ?aid ?lid)
       (figure ?lid ?fid))
 :rhs ((figure ?eci ?fid)))

(kbop:rule
 :lhs ((eci ?id ?eci)
       (affected ?id ?aid)
       (location ?aid ?lid)
       (ground ?lid ?gid))
 :rhs ((ground ?eci ?gid)))

;;; ------------------------------------------------------------
;;; Resolution rules -- map specific IDs to objects.

;; TRIPS sometimes maps "the table" to ont::chart, sometimes to
(kbop:rule
 :lhs ((instance-of ?id ?type)
       (:set-member ?type (set-fn ont::chart ont::table ont::geo-formation)))
 :rhs ((scene-objs ?id (set-fn grd))))

;; The user might say "block 4" or "b4". These map into a list.
(kbop:rule
 :lhs ((name-of ?id (list-fn ?type ?block-num))
       (:set-member ?type (set-fn w::block w::b))
       (:stormat ?name "B~a" (?block-num))
       (:in scene (name ?obj ?name)))
 :rhs ((scene-objs ?id (set-fn ?obj))))

;; When the user just says "number 4".
(kbop:rule
 :lhs ((name-of ?id (list-fn ?block-num))
       (:stormat ?name "B~a" (?block-num))
       (:in scene (name ?obj ?name)))
 :rhs ((scene-objs ?id (set-fn ?obj))))

;;; ------------------------------------------------------------
;;; Find objects that match constraints.

;;; Collect up the constraints. Filter them to be the items that match
;;; all the constraints.
(kbop:rule
 :lhs ((constraints ?id ?csid)
       ;; Any named object in the scene.
       (:aggregate ?all-objs ?obj
                   (:in scene (name ?obj ?any-name)))
       ;; By type
       (some (and (constraint ?csid ?type-cid)
                  (isa ?type-cid ?any-type)
                  (scene-objs ?type-cid ?type-objs))
             (:assign ?type-objs ?all-objs))
       ;; By color
       (some (and (constraint ?csid ?color-cid)
                  (color ?color-cid ?any-color)
                  (scene-objs ?color-cid ?color-objs))
             (:assign ?color-objs ?all-objs));
       ;; Intersection
       (:intersection ?objs ?all-objs ?type-objs ?color-objs))
 :rhs-unstore ((scene-objs ?csid ?any))
 :rhs ((scene-objs ?csid ?objs)))

;; Type constraint.
(kbop:rule
 :lhs ((constraints ?id ?csid)
       (constraint ?csid ?cid)
       (isa ?cid ?type)
       ;; Collect the allowed objects.
       (:aggregate ?objs ?obj
                   (:in scene (isa ?obj ?type))))
 :rhs ((scene-objs ?cid ?objs)))

;; Color constraint.
(kbop:rule
 :lhs ((constraints ?id ?csid)
       (constraint ?csid ?cid)
       (color ?cid ?color)
       ;; Collect the allowed objects.
       (:aggregate ?objs ?obj
                   (:in scene (color-of ?obj ?color))))
 :rhs ((scene-objs ?cid ?objs)))

