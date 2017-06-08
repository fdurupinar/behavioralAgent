;;; ------------------------------------------------------------
;;; Rules that aggregate content for bioagent lookup queries.
;;;
(:in-context collab-context)

;;; ------------------------------------------------------------
;;; Recognize a goal to determine or learn. This is basically what we
;;; get for the user's utterance "I want to find a treatment for
;;; pancreatic cancer."

(<< (is-determine-goal ?goal)
    (get-goal-type ?goal ?type)
    (:set-member ?type (set-fn ont::determine ont::learn)))

;;; ------------------------------------------------------------
;;; Disease of interest

;;; This is a nasty lookup. We ought to be doing a normalization
;;; thing, like BW does.
(<< (get-disease-of-interest ?goal ?did)
    (this-goals-disease-of-interest ?goal ?did))

;; Get it directly, if possible.
;; e.g., from "are there any drugs for pancreatic cancer?"
(<< (this-goals-disease-of-interest ?goal ?did)
    (what ?goal ?what)
    (instance-of ?what ONT::LEARN)
    (neutral ?what ?neut)
    (affected ?neut ?did)
    (instance-of ?did ?disease-type)
    (:sub-category ONT::MEDICAL-DISORDERS-AND-CONDITIONS ?disease-type)
    )

;; or "are there any drugs for pancreatic cancer?"
(<< (this-goals-disease-of-interest ?goal ?did)
    (query ?goal ?qid)
    (instance-of ?qid ONT::USE)
    (reason ?qid ?rid)
    (ground ?rid ?did)
    (instance-of ?did ?disease-type)
    (:sub-category ONT::MEDICAL-DISORDERS-AND-CONDITIONS ?disease-type)
    )

;; or "what drug should i use for pancreatic cancer?"
(<< (this-goals-disease-of-interest ?goal ?did)
    (query ?goal ?qid)
    (instance-of ?qid ONT::ASSOC-WITH)
    (ground ?qid ?did)
    (instance-of ?did ?disease-type)
    (:sub-category ONT::MEDICAL-DISORDERS-AND-CONDITIONS ?disease-type)
    )

;;; If this goal didn't have it, check the parent.
(<< (get-disease-of-interest ?goal ?did)
    (:uninferrable (this-goals-disease-of-interest ?goal ?did))
    (find-collab-parent-goal ?goal ?parent-goal)
    (get-disease-of-interest ?parent-goal ?did))

;;; ------------------------------------------------------------
;;; Cause and effect result for protein

(<< (get-result-for-protein ?what ?result-id)
    (suchthat ?what ?st)
    (instance-of ?st ont::cause-effect)
    (result ?st ?result-id))

(<< (get-result-for-protein ?what ?result-id)
    (suchthat ?what ?st)
    (instance-of ?st ont::cause)
    (outcome ?st ?result-id))

;;; ------------------------------------------------------------
;;; Gene target

;; (<< (get-gene-target ?wti ?target)
;;     (mod ?wti ?m)
;;     (neutral1 ?m ?target)
;;     (instance-of ?target ont::gene))

(<< (get-gene-target ?wti ?target)
    (suchthat ?wti ?m)
    (affected ?m ?target)
    (instance-of-some ?target
                      (set-fn ont::gene
                              ont::gene-protein
                              ont::protein
                              ont::protein-family)))


;;; ------------------------------------------------------------
;;; Lookup drug(s) returned by query to bioagents.

(<< (find-drugs-for-query ?query-id ?drugs)
    (some (drug ?query-id ?drugs)
          (drugs ?query-id ?drugs)))

