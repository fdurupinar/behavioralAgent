;;; ------------------------------------------------------------
;;; Rules that aggregate content for EKB translation.
;;;

(:in-context collab-context)

;; ------------------------------------------------------------
;; Generating parts of EKB terms

(<< (get-active-term-xml ?term-id ?ekb-xml)
    (:uninferrable (active ?term-id ?is-active))
    (:stormat ?ekb-xml ""))

(<< (get-active-term-xml ?term-id ?ekb-xml)
    (:aggregate ?active-xmls ?event-xml
                (active ?term-id ?is-active)
                (:stormat ?event-xml "<active>~a</active>" (?is-active)))
    (:nonempty ?active-xmls)
    (:stormat ?ekb-xml "~{~a~}" (?active-xmls)))

(<< (get-inevent-term-xml ?term-id ?ekb-xml)
    (:uninferrable (inevent ?term-id ?x))
    (:stormat ?ekb-xml ""))

(<< (get-inevent-term-xml ?term-id ?ekb-xml)
    (:aggregate ?event-xmls ?event-xml
                (inevent ?term-id ?event-id)
                (:stormat ?event-xml "<event id=\"~a\"/>" (?event-id)))
    (:nonempty ?event-xmls)
    (:stormat ?ekb-xml "<inevent>~{~a~}</inevent>" (?event-xmls)))

(<< (get-site-term-xml ?term-id ?ekb-xml)
    (:uninferrable
     (site-name ?term-id ?site-name)
     (site-code ?term-id ?site-code)
     (site-pos ?term-id ?site-pos))
    (:stormat ?ekb-xml ""))

;; <site><name>Threonine</name><code>T</code><pos>185</pos></site>
(<< (get-site-term-xml ?term-id ?ekb-xml)
    (:aggregate ?site-xmls ?site-xml
                (site-name ?term-id ?site-name)
                (site-code ?term-id ?site-code)
                (site-pos ?term-id ?site-pos)
                (:stormat ?site-xml "<site><name>~a</name><code>~a</code><pos>~a</pos></site>"
                          (?site-name ?site-code ?site-pos)))
    (:nonempty ?site-xmls)
    (:stormat ?ekb-xml "~{~a~}" (?site-xmls)))

(<< (get-drum-terms-xml ?term-id ?drum-terms-xml)
    (:uninferrable
     (db-term-id ?term-id ?dbid)
     (db-term-name ?term-id ?dbid ?name)
     ;; (db-term-matched ?term-id ?dbid ?matched)
     (db-term-score ?term-id ?dbid ?score))
    (:stormat ?drum-terms-xml ""))

(<< (get-drum-terms-xml ?term-id ?drum-terms-xml)
    (:aggregate ?drum-term-xmls ?drum-term-xml
                (db-term-id ?term-id ?dbid)
                (db-term-name ?term-id ?dbid ?name)
                ;; (db-term-matched ?term-id ?dbid ?matched)
                (db-term-score ?term-id ?dbid ?score)
                ;; (FIXME Also get <types><type>...</type>...</type>...</types>)
                ;; (FIXME Also get <xrefs><xref dbid=\"...\"/>...</xrefs>)
                (:stormat ?drum-term-xml "<drum-term dbid=\"~a\" match-score=\"~a\" name=\"~a\" />"
                          (?dbid ?score ?name)))
    (:stormat ?drum-terms-xml "<drum-terms>~{~a~}</drum-terms>" (?drum-term-xmls)))

(<< (get-dbid-attribute ?term-id ?ekb-xml)
    (:uninferrable (dbid ?term-id ?dbid))
    (:stormat ?ekb-xml ""))

(<< (get-dbid-attribute ?term-id ?ekb-xml)
    ;; (dbid ?term-id ?dbid)
    (:aggregate ?dbids ?dbid
                (db-term-id ?term-id ?dbid))
    (:stormat ?ekb-xml " dbid=\"~{~a~^|~}\"" (?dbids)))

(<< (get-name-xml ?term-id ?name-xml)
    (:uninferrable (name ?term-id ?name))
    (:stormat ?name-xml ""))

(<< (get-name-xml ?term-id ?name-xml)
    (name ?term-id ?name)
    (:stormat ?name-xml "<name>~a</name>" (?name)))

;; ------------------------------------------------------------
;; Formatting EKB terms

(<< (get-term-xml ?term-id ?ekb-xml)
    ;; Get the information for the term.
    (instance-of ?term-id ?type)
    (:uninferrable (m-sequence ?term-id ?sub-term-ids))
    (get-name-xml ?term-id ?name-xml)
    (get-dbid-attribute ?term-id ?dbid-attr)
    (get-inevent-term-xml ?term-id ?inevent-xml)
    (get-site-term-xml ?term-id ?site-xml)
    (get-active-term-xml ?term-id ?active-xml)
    (get-drum-terms-xml ?term-id ?drum-terms-xml)
    ;; Format the EKB XML string.
    (:stormat ?ekb-xml
              "<TERM id=\"~a\"~a><features>~a~a~a</features><type>ONT::~a</type>~a~a</TERM>"
              (?term-id ?dbid-attr ?inevent-xml ?site-xml ?active-xml ?type ?name-xml ?drum-terms-xml)))

(<< (get-term-xml ?term-id ?ekb-xml)
    (get-compound-term-xml ?term-id ?ekb-xml))

(<< (get-compound-term-xml ?term-id ?ekb-xml)
    ;; Get the information for the term.
    (instance-of ?term-id ?type)
    (m-sequence ?term-id ?sub-term-ids)
    (get-inevent-term-xml ?term-id ?inevent-xml)
    (get-site-term-xml ?term-id ?site-xml)
    (:aggregate ?component-xmls ?component-xml
                (:set-member ?sub-term-id ?sub-term-ids)
                (:stormat ?component-xml
                          "<component id=\"~a\"/>"
                          (?sub-term-id)))
    (:aggregate ?sub-term-xmls ?sub-term-xml
                (:set-member ?sub-term-id ?sub-term-ids)
                (get-term-xml ?sub-term-id ?sub-term-xml))
    ;; (:stormat ?component-term-xml
    ;;           "~{~a~}"
    ;;           (?component-xmls))
    ;; Format the EKB XML string.
    (:stormat ?ekb-xml
              "<TERM id=\"~a\"><features>~a~a</features><type>ONT::~a</type><components>~{~a~}</components></TERM>~{~a~}"
              (?term-id ?inevent-xml ?site-xml ?type ?component-xmls ?sub-term-xmls)))

;; ------------------------------------------------------------
;; Getting relevant terms for EKB entries.

(<< (relevant-event-term ?event-id ?term-id)
    (site ?event-id ?term-id))

(<< (relevant-event-term ?event-id ?term-id)
    (agent ?event-id ?term-id))

(<< (relevant-event-term ?event-id ?term-id)
    (affected ?event-id ?term-id))

(<< (relevant-event-term ?event-id ?term-id)
    (affected1 ?event-id ?term-id))

(<< (relevant-event-term ?event-id ?term-id)
    (from ?event-id ?term-id))

(<< (relevant-event-term ?event-id ?term-id)
    (to ?event-id ?term-id))

(<< (ekb-term-id ?ekb-id ?term-id)
    (ekb-event ?ekb-id ?event-id)
    (relevant-event-term ?event-id ?term-id))

(<< (relevant-sub-term ?term-id ?other-term-id)
    (m-sequence ?term-id ?sub-term-ids)
    (:set-member ?other-term-id ?sub-term-ids))
