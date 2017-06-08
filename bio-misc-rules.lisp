;;; ------------------------------------------------------------
;;; Rules that aggregate content for misc bio reasoning.
;;;
(:in-context collab-context)

;;; ------------------------------------------------------------
;;; Helper method for instance testing.

(<< (instance-of-some ?thing ?set)
    (:bound ?set)
    (instance-of ?thing ?category)
    (:set-member ?category ?set))

;;; ------------------------------------------------------------
;;; Added when find-drug goal changed from :affected to :neutral. There
;;; are lots of places where we refered to either of these. This horn
;;; clause lets us handle both.
(<< (refers-to ?id ?target)
    (affected ?id ?target))

(<< (refers-to ?id ?target)
    (neutral ?id ?target))

;;; ------------------------------------------------------------
;;; Getting the disease which is affected by a cause.

(<< (affected-by-protein ?result ?did)
    ;; ...an increase...
    (instance-of ?result ont::increase)
    (affected ?result ?did))

(<< (affected-by-protein ?result ?did)
    ;; ...that produces...
    (instance-of ?result ont::produce)
    (affected-result ?result ?did))

;;; ------------------------------------------------------------
;;; Getting dbname and dbid from target terms.

(<< (db-name-and-id ?target ?dbname ?dbid)
    (dbname ?target ?dbname)
    (dbid ?target ?dbid))

(<< (db-name-and-id ?target "UNKNOWN" "UNKNOWN")
    (:uninferrable
     (dbname ?target ?dbname)
     (dbid ?target ?dbid)))

