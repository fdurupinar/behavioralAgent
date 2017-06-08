;;;; Support for verifying structures.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; Verify an envisionment
;;;
;;; The methods are not quite mutually exclusive. We use priorities to
;;; control the order in which the executive attempts them.

(kbop:method
 :matches ((verify ?envisionment))
 :priority 2
 :pre ((insufficient-block-count ?envisionment))
 :on-ready ((:note "not enough blocks")
            (:store (verification-result ?envisionment INSUFFICIENT-BLOCKS)))
 :result success)

(kbop:method
 :matches ((verify ?envisionment))
 :priority 1
 :pre ((insufficient-block-colors ?envisionment))
 :on-ready ((:note "not enough of requested colors")
            (:store (verification-result ?envisionment INSUFFICIENT-BLOCKS)))
 :result success)

;; Verify successful.
(kbop:method
 :matches ((verify ?envisionment))
 :priority 0
 ;; :pre ((:uninferrable (plan-for ?envisionment ?plan-name)))
 :on-ready ((:note "seems okay")
            (:store (verification-result ?envisionment OK)))
 :result success)

;;; ------------------------------------------------------------
;;; Rules for verification
;;;
(:in-context collab-context)

(<< (insufficient-block-count ?envisionment)
    (:uninferrable (plan-for ?envisionment ?plan-name))
    ;; Count the number of blocks in the envisionment.
    (:aggregate ?blocks-needed ?block
                (:in ?envisionment (isa ?block block)))
    ;; Count the number of blocks in the scene.
    (:aggregate ?blocks-available ?block
                (:in scene (isa ?block block)))
    (:cardinality ?blocks-needed ?nbr-blocks-needed)
    (:cardinality ?blocks-available ?nbr-blocks-available)
    ;; We need too many?
    (:> ?nbr-blocks-needed ?nbr-blocks-available))

(<< (insufficient-block-colors ?envisionment)
    (:uninferrable (plan-for ?envisionment ?plan-name))
    ;; Aggregate specified colors
    (:aggregate
     ?specified-colors ?color
     (:in ?envisionment (and (color-of ?block ?color)
                             (isa ?block block))))
    ;; Now aggregate color insufficiencies
    (:aggregate
     ?insufficient-colors ?color
     (:set-member ?color ?specified-colors)
     (:aggregate
      ?blocks-needed ?block
      (:in ?envisionment (and (color-of ?block ?color)
                              (isa ?block block))))
     (:aggregate
      ?blocks-available ?block
      (:in scene (and (color-of ?block ?color)
                      (isa ?block block))))
     ;; Get cardinalites for needed vs avaialble.
     (:cardinality ?blocks-needed ?nbr-blocks-needed)
     (:cardinality ?blocks-available ?nbr-blocks-available)
     ;; We need too many?
     (:> ?nbr-blocks-needed ?nbr-blocks-available))
    (:nonempty ?insufficient-colors))

