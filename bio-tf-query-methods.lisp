;;; ------------------------------------------------------------
;;; Bio methods defining the goal hierarchy and exec behavior for
;;; transcription-factor queries (handled by agent developed by Xue
;;; Zhang at Tufts).
;;;
(:in-context exec-methods)

;; ------------------------------
;; IS-TF-TARGET
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-if ONT::MODULATE ?goal ?what)
       (agent ?what ?agent)
       (:uninferrable (instance-of ?agent ONT::PHARMACOLOGIC-SUBSTANCE))
       )
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-if ONT::MODULATE ?goal ?what)
       (agent ?what ?agent)
       (:uninferrable (instance-of ?agent ONT::PHARMACOLOGIC-SUBSTANCE))
       (get-term-xml ?agent ?agent-xml)
       (affected ?what ?affected)
       (get-term-xml ?affected ?affected-xml))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (is-tf-target
                                      :tf ?agent-xml
                                      :target ?affected-xml)))
            (:dbug "Ask TF if IS-TF-TARGET for agent" ?agent
                   "and affected" ?affected)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

;; ------------------------------
;; FIND-TARGET-TF
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (modulated-by-what ?what ?affected))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (modulated-by-what ?what ?affected)
       (get-term-xml ?affected ?affected-xml))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-target-tf
                                      :target ?affected-xml)))
            (:store (target ?query-id ?affected))
            (:dbug "Ask TF to FIND-TARGET-TF"
                   "for affected" ?affected)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))


;; ------------------------------
;; FIND-TF-TARGET
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::GENE ?goal ?what))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::GENE ?goal ?what)
       (agent ?query ?agent)
       (get-term-xml ?agent ?agent-xml)
       (instance-of ?query ONT::MODULATE)
       (affected ?query ?what))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-tf-target
                                      :tf ?agent-xml)))
            (:store (target ?query-id ?agent))
            (:dbug "Ask TF to FIND-TF-TARGET"
                   "for agent" ?agent)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

;; ------------------------------
;; FIND-PATHWAY-GENE

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::SIGNALING-PATHWAY ?goal ?what))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :priority 2
 :pre ((is-ask-what ONT::SIGNALING-PATHWAY ?goal ?what)
       (gene-for-what ?what ?gene)
       (get-db-name ?what ?dbname)
       (get-term-xml ?gene ?gene-xml))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-pathway-db-gene
                                      :database (?dbname)
                                      :gene ?gene-xml)))
            (:store (target ?query-id ?gene))
            (:dbug "Ask TF to FIND-PATHWAY-DB-GENE"
                   "for gene" ?gene "in db" ?dname)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :priority 1
 :pre ((is-ask-what ONT::SIGNALING-PATHWAY ?goal ?what)
       (gene-for-what ?what ?gene)
       (get-term-xml ?gene ?gene-xml))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-pathway-gene
                                      :gene ?gene-xml)))
            (:store (target ?query-id ?gene))
            (:dbug "Ask TF to FIND-PATHWAY-GENE"
                   "for gene" ?gene)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

;; ------------------------------
;; FIND-GENE-PATHWAY

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::GENE ?goal ?what)
       (query-have-property-pathway ?goal ?pathway))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::GENE ?goal ?what)
       (query-have-property-pathway ?goal ?pathway)
       (get-term-xml ?pathway ?pathway-xml))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-gene-pathway
                                      :pathway ?pathway-xml)))
            (:store (target ?query-id ?pathway))
            (:dbug "Ask TF to FIND-GENE-PATHWAY"
                   "for pathway" ?pathway)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

;; ------------------------------
;; Shared/common pathways and transcription factors for genes.
;;
;; Initially I implemented thes using: FIND-COMMON-PATHWAY-GENES and
;; FIND-COMMON-TF-GENES. Apparently, the FIND-COMMON- messages are for
;; finding *unions* instead of intersections. Xue suggested on 2 May
;; 2017 that I should be sending FIND-PATHWAY-GENE-KEYWORD instead.

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::SIGNALING-PATHWAY ?goal ?what)
       (query-share-property-genes ?goal ?genes))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::SIGNALING-PATHWAY ?goal ?what)
       (query-share-property-genes ?goal ?genes)
       (:aggregate ?gene-xmls ?gene-xml
                   (:elt-at ?genes ?index ?gene)
                   (get-term-xml ?gene ?gene-xml))
       (:stormat ?genes-xml "~{~A~}" (?gene-xmls)))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-pathway-gene-keyword
                                      :keyword ("signaling pathway")
                                      :gene ?genes-xml)))
            (:store (target ?query-id ?genes))
            (:dbug "Ask TF to FIND-PATHWAY-GENE-KEYWORD"
                   "for genes" ?genes)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (query-share-property-genes ?goal ?genes))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (query-share-property-genes ?goal ?genes)
       (:aggregate ?gene-xmls ?gene-xml
                   (:elt-at ?genes ?index ?gene)
                   (get-term-xml ?gene ?gene-xml))
       (:stormat ?genes-xml "~{~A~}" (?gene-xmls)))
 :on-ready ((:gentemp ?query-id "tf-query-")
            (:store (query ?query-id (find-target-tf
                                      :target ?genes-xml)))
            (:store (target ?query-id ?genes))
            (:dbug "Ask TF to FIND-TARGET-TF"
                   "for genes" ?genes)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

;;; ------------------------------------------------------------
;;; Some rules

(:in-context collab-context)

(<< (get-db-name ?what ?dbname)
    (name ?what W::REACTOME)
    (:assign ?dbname Reactome))

(<< (get-db-name ?what ?dbname)
    (name ?what W::KEGG)
    (:assign ?dbname KEGG))

(<< (modulated-by-what ?what ?affected)
    (agent ?query ?what)
    (instance-of ?query ONT::MODULATE)
    (affected ?query ?affected))

(<< (gene-for-what ?what ?gene)
    (suchthat ?what ?st)
    (neutral1 ?st ?tf)
    (or (assoc-with ?tf ?gene)
        (:assign ?gene ?tf))
    (instance-of ?gene ont::gene-protein))

(<< (gene-for-what ?what ?gene)
    (suchthat ?what ?st)
    (affected ?st ?gene)
    (instance-of ?gene ont::gene-protein))

(<< (query-have-property-pathway ?goal ?pathway)
    (query ?goal ?query)
    (ground-for-query ?query ?ground)
    (assoc-with ?ground ?pathway))

(<< (query-share-property-genes ?goal ?genes)
    (query ?goal ?query)
    (ground-for-query ?query ?ground)
    (instance-of ?ground ONT::SEQUENCE)
    (logicalop-sequence ?ground ?genes))

(<< (ground-for-query ?query ?ground)
    (instance-of ?query ont::have-property)
    (formal ?query ?formal)
    (ground ?formal ?ground))

(<< (ground-for-query ?query ?ground)
    (instance-of-some ?query (set-fn ont::have ont::share-property))
    (neutral ?query ?ground))
