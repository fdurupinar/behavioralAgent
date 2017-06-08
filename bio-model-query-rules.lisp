;;; ------------------------------------------------------------
;;; Rules that aggregate content for model queries.
;;;
(:in-context collab-context)

;; ------------------------------------------------------------
;; Some static facts for symbol-to-string conversion for TRA queries.

(<< (get-term-for ?property ?term)
    (instance-of ?property ?type)
    (ekb-term-for ?type ?term))

(<< (get-term-for ?property ?term)
    (lex ?property ?type)
    (ekb-term-for ?type ?term))

(<< (ekb-term-for ?type ?term)
    (:set-member ?type (set-fn ONT::HIGH-VAL W::HIGH))
    (:assign ?term "high"))

(<< (ekb-term-for ont::low-val ?term)
    (:assign ?term "low"))

(<< (ekb-term-for ont::always ?term)
    (:assign ?term "always_value"))

(<< (ekb-term-for ont::event-time-rel-culmination ?term)
    (:assign ?term "eventual_value"))

(<< (ekb-term-for ont::whole-complete ?term)
    (:assign ?term "total"))

(<< (ekb-term-for ont::increase ?term)
    (:assign ?term "multiple"))

(qualitative-answer-for 1.0 true)

(<< (qualitative-answer-for ?prob ?qualitative-answer)
    (:different ?prob 1.0)
    (:assign ?qualitative-answer false))

;; ------------------------------------------------------------
;; Figure out which entity a query is about.

;; Given a query, it's :affected is the entity if it's not a quantity.
(<< (query-about-entity ?query ?entity)
    (:props ?query :affected ?entity)
    (:uninferrable (instance-of ?entity ont::quantity)))

;; Given a query about a quantity, trace through the figure.
(<< (query-about-entity ?query ?entity)
    (:props ?query :affected ?quantity)
    (:props ?quantity :instance-of ont::quantity :figure ?entity))

;; Given an instance of have-property about a quantity, trace through the figure.
(<< (query-about-entity ?query ?entity)
    (:props ?query :instance-of ont::have-property :neutral ?quantity)
    (:props ?quantity :instance-of ont::quantity :figure ?entity))

;; Given an instance of have-property about a non-quantity, that's the entity.
(<< (query-about-entity ?query ?entity)
    (:props ?query :instance-of ont::have-property :neutral ?entity)
    (:uninferrable (instance-of ?entity ont::quantity)))

;; ------------------------------------------------------------
;; Get the value, e.g., HIGH-VAL, LOW-VAL, etc.

;; The value is hanging off the query in the formal.
(<< (query-about-explicit-value ?query ?value-string)
    (:props ?query :instance-of ont::have-property :formal ?value-property)
    (:uninferrable
     (instance-of-some ?value-property (set-fn ont::temporary)))
    (get-term-for ?value-property ?value-string))

;; The value is from at-loc, e.g., "at a high value"
(<< (query-about-explicit-value ?query ?value-string)
    (instance-of-some ?query (set-fn ont::activity-ongoing))
    (location ?query ?loc)
    (:props ?loc :instance-of ont::at-loc :ground ?level)
    (:props ?level :instance-of ont::level :mod ?value)
    (get-term-for ?value ?value-string))

;; If we can't infer a specific value --> NONE.
(<< (query-about-value ?query ?value-string)
    (:uninferrable
     (query-about-explicit-value ?query ?value-string))
    (:assign ?value-string NONE))

;; If we can infer a specific value, bind that.
(<< (query-about-value ?query ?value-string)
    (query-about-explicit-value ?query ?value-string))

;; ------------------------------------------------------------
;; Get a bunch of parameters for a TRA query given a goal.

(<< (goal-query-parameters ?goal ?term-of-quantity ?frequency-string ?value-string)
    (query ?goal ?query)
    (query-parameters ?query ?term-of-quantity ?frequency-string ?value-string))

;; ------------------------------------------------------------
;; Get a modifier on a quantity, defaulting to "total"

(<< (quantity-modifier-string ?quantity ?modifier-string)
    (mod ?quantity ?mod)
    (get-term-for ?mod ?modifier-string)) ;; WHOLE-COMPLETE -> "total"

(<< (quantity-modifier-string ?quantity ?modifier-string)
    (:uninferrable
     (mod ?quantity ?mod)
     (get-term-for ?mod ?modifier-string))
    (:assign ?modifier-string "total"))

;; ------------------------------------------------------------
;; Get a condition for a TRA query given a goal.

;; e.g., (:type “multiple” :value 10.0 :quantity (:type “total” :entity (:description “$EKB_DUSP6”)))
(<< (goal-query-condition ?cond ?about-term ?type-string ?value ?quantity-string)
    (:props ?cond :instance-of ont::pos-condition :ground ?factor)
    (:props ?factor :affected ?quantity :extent ?extent)
    (:props ?quantity :instance-of ont::quantity :figure ?about-term)
    (:props ?extent :instance-of ont::extent-predicate :ground ?extent-qty)
    (:props ?extent-qty :instance-of ont::quantity :amount ?amount)
    (:props ?amount :instance-of ont::number :value ?value)
    (quantity-modifier-string ?quantity ?quantity-string) ;; e.g., "total"
    (get-term-for ?factor ?type-string) ;; INCREASE -> :type "multiple"
    ;;(:assign ?type-string "multiple")
    )

;; ------------------------------------------------------------
;; Get a bunch of parameters for a TRA query given the query context entity itself.

;; Entity/amount vanishes (disappears/depeletes)
(<< (query-parameters ?query ?term-of-quantity ?frequency-string ?value-string)
    (instance-of-some ?query (set-fn ont::disappear ont::deplete))
    (query-about-entity ?query ?term-of-quantity)
    (:assign ?frequency-string "eventual_value")
    (:assign ?value-string "low"))

;; Entity/amount sustained over time (activity-ongoing).  No value string.
(<< (query-parameters ?query ?term-of-quantity ?frequency-string ?value-string)
    (instance-of-some ?query (set-fn ont::activity-ongoing))
    (query-about-value ?query ?value-string)
    (query-about-entity ?query ?term-of-quantity)
    (:assign ?frequency-string "sustained"))

;; Amount is at a given level at some frequency.
(<< (query-parameters ?query ?term-of-quantity ?frequency-string ?value-string)
    (:props ?query :instance-of ont::have-property
            :frequency ?frequency-property
            :time- ?time-property)  ; There is NO time property.
    (query-about-entity ?query ?term-of-quantity)
    (query-about-value ?query ?value-string)
    (get-term-for ?frequency-property ?frequency-string))

;; Amount is at a given level at some time.
(<< (query-parameters ?query ?term-of-quantity ?time-string ?value-string)
    (:props ?query :instance-of ont::have-property
            :frequency- ?frequency-property ; There is NO frequency property
            :time ?time-property)
    (query-about-entity ?query ?term-of-quantity)
    (query-about-value ?query ?value-string)
    (get-term-for ?time-property ?time-string)
    ;; (ekb-term-for ?value-type ?value-string)
    )

;; Transience (temporary).  No value string.
(<< (query-parameters ?query ?term-of-quantity ?frequency-string ?value-string)
    (:props ?query :instance-of ont::have-property
            :formal ?transient-property
            :frequency- ?frequency-property)  ; This means there is *no* frequency.
    (query-about-value ?query ?value-string)
    (query-about-entity ?query ?term-of-quantity)
    ;;(instance-of ?frequency-property ?frequency-type)
    (instance-of-some ?transient-property (set-fn ont::temporary))
    (:assign ?frequency-string "transient"))

;; ------------------------------------------------------------
;; Generate TRA queries with rules using params.

(<< (get-satisfies-pattern-query ?type ?ekb-description ?value ?model-id ?the-query)
    (:same ?value NONE)
    (find-model-string ?model-id ?model-string)
    (:assign ?the-query
             (satisfies-pattern
              :pattern
              (:type ?type :entities ((:description ?ekb-description)))
              :model ?model-string)))

(<< (get-satisfies-pattern-query ?type ?ekb-description ?value ?model-id ?the-query)
    (:different ?value NONE)
    (find-model-string ?model-id ?model-string)
    (:assign ?the-query
             (satisfies-pattern
              :pattern
              (:type ?type :entities ((:description ?ekb-description))
                     :value (:type "qualitative" :value ?value))
              :model ?model-string)))

(<< (get-satisfies-pattern-query-cond ?type ?ekb-description ?value ?model-id
                                      ?the-query ?conditions)
    (:same ?value NONE)
    (find-model-string ?model-id ?model-string)
    (:assign ?the-query
             (satisfies-pattern
              :pattern
              (:type ?type :entities ((:description ?ekb-description)))
              :model ?model-string
              :conditions ?conditions)))

(<< (get-satisfies-pattern-query-cond ?type ?ekb-description ?value ?model-id
                                      ?the-query ?conditions)
    (:different ?value NONE)
    (find-model-string ?model-id ?model-string)
    (:assign ?the-query
             (satisfies-pattern
              :pattern
              (:type ?type :entities ((:description ?ekb-description))
                     :value (:type "qualitative" :value ?value))
              :model ?model-string
              :conditions ?conditions)))

