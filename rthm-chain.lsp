;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****c* rthm-seq-map/rthm-chain
;;; NAME 
;;; rthm-chain
;;;
;;; File:             rthm-chain.lsp
;;;
;;; Class Hierarchy:  named-object -> linked-named-object -> sclist -> 
;;;                   circular-sclist -> assoc-list -> recursive-assoc-list ->
;;;                   sc-map -> rthm-seq-map -> rthm-chain
;;; 
;;; Version:          1.0.0-beta1
;;;
;;; Project:          slippery chicken (algorithmic composition)
;;;
;;; Purpose:          Algorithmic generation of rthm-seqs that include
;;;                   slower-moving counterpoint and a means to control
;;;                   activity development through curves.  Here we generate a
;;;                   rthm-seq-map and its associated palette algorithmically.
;;;
;;;                   Say we have 9 irregular 1 beat duration patterns; these
;;;                   would enter in the sequence defined by (procession x 9)
;;;                   where x would be the number of patterns to generate. 
;;; 
;;;                   Rests are inserted at regular but changing intervals e.g
;;; 
;;;                   3x every 2 beats (6)
;;;                   2x every 3 beats (6)
;;;                   3x every 5 beats (15)
;;;                   2x every 8 beats (16)
;;; 
;;;                   e, q, and q. rests are used by default, in a sequence
;;;                   determined by a recurring-event instance.
;;; 
;;;                   In order to make music that 'progresses' we have curves
;;;                   with y values from 1-10 indicating how much activity
;;;                   there should be: 1 would mean only 1 in 10 beats would
;;;                   have notes in/on them, 10 would indicate that all do.  We
;;;                   use the patterns given in activity-levels::init-instance
;;;                   below, where 1 means 'play', 0 means 'rest'.  There are
;;;                   three examples of each level so that if we stick on one
;;;                   level of activity for some time we won't always get the
;;;                   same pattern: these will instead be cycled through.
;;; 
;;;                   A slower moving (bass) line is also added that is made up
;;;                   of 2 or 3 beat groups---if the activity curve indicates a
;;;                   rest, then the whole 2-3 beat group is omitted.
;;; 
;;;                   There are also 'sticking points' where a rhythm will be
;;;                   repeated a certain number of times (either s,e,e., or q
;;;                   by default).  Sticking happens after rests.  This can be
;;;                   controlled with an activity envelope too, also indicating
;;;                   one of the 10 patterns above (but also including 0).  A 0
;;;                   or 1 unit here would refer to a certain number of repeats
;;;                   (1) or none (0).  How many repeats could be determined by
;;;                   something like: (procession 34 '(2 3 5 8 13) :peak 1
;;;                   :expt 3) There's always a slower group to accompany the
;;;                   sticking points: simply the next in the sequence,
;;;                   repeated for as long as we stick
;;; 
;;;                   The harmonic-rthm curve specifies how many slower-rthms
;;;                   will be combined into a rthm-seq (each rthm-seq has a
;;;                   single harmony).  The default is 2 bars (slower-rthms)
;;;                   per rthm-seq.
;;; 
;;;
;;; Author:           Michael Edwards: m@michael-edwards.org
;;;
;;; Creation date:    4th February 2010
;;;
;;; $$ Last modified: 19:03:14 Mon Apr 30 2012 BST
;;;
;;; SVN ID: $Id$
;;;
;;; ****
;;; Licence:          Copyright (c) 2010 Michael Edwards
;;;
;;;                   This file is part of slippery-chicken
;;;
;;;                   slippery-chicken is free software; you can redistribute it
;;;                   and/or modify it under the terms of the GNU General
;;;                   Public License as published by the Free Software
;;;                   Foundation; either version 3 of the License, or (at your
;;;                   option) any later version.
;;;
;;;                   slippery-chicken is distributed in the hope that it will
;;;                   be useful, but WITHOUT ANY WARRANTY; without even the
;;;                   implied warranty of MERCHANTABILITY or FITNESS FOR A
;;;                   PARTICULAR PURPOSE.  See the GNU General Public License
;;;                   for more details.
;;;
;;;                   You should have received a copy of the GNU General Public
;;;                   License along with slippery-chicken; if not, write to the
;;;                   Free Software Foundation, Inc., 59 Temple Place, Suite
;;;                   330, Boston, MA 02111-1307 USA
;;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 02.12.11 SEAN: changed robodoc header to reflect class hierarchy

(eval-when (compile)
  (declaim (optimize (speed 3) (safety 1) (space 0) (debug 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :slippery-chicken)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; the rthm-seq-palette we generate to hold the 1-beat rthms as well as the
;;; slower-rthms will be the palette slot of the map.  the map is the data
;;; slot.  The transition from one group of rhythms to the next over the whole
;;; output (i.e. not one unit to another within e.g. the 1-beat rhythms) is
;;; always done with the fibonacci method.

(defclass rthm-chain (rthm-seq-map) 
  ;; the 1-beat rthms: these are just a list with sublists of of rthms: we
  ;; don't need ids for these.  Each sublist represents the repertoire of rthms
  ;; we'll use in the procession and a transition will be made over the course
  ;; of the generated piece to move through the sublists according to a
  ;; fibonacci transition algorithm.  Each sublist must contain the same number
  ;; of rthms but their number and the number of sublists is open.
  ((1-beat-rthms :accessor 1-beat-rthms :type list :initarg :1-beat-rthms
                 :initform nil)
   ;; whether we'll use fibonacci transitions or the procession algorithm in
   ;; the generation of the 1-beat rhythm order
   (1-beat-fibonacci :accessor 1-beat-fibonacci :type boolean
                     :initarg :1-beat-fibonacci :initform nil)
   ;; whether we'll use fibonacci transitions or the procession algorithm in
   ;; the generation of the 2/3-beat rhythm order i.e. the order in which each
   ;; 2beat unit is used when necessary, not the order in which we select a
   ;; 2beat or 3beat unit.  That is decided by the next element in the data
   ;; slot of rcs (rthm-chain-slow); this just rotates around 
   ;; '(2 3 2 2 3 2 2 3 3 3))))
   (slow-fibonacci :accessor slow-fibonacci :type boolean 
                   :initarg :slow-fibonacci :initform nil)
   ;; how many 1-beat rhythms are their in a group?
   (num-1-beat-rthms :accessor num-1-beat-rthms :type integer :initform 0)
   ;; how many 1-beat groups are there?
   (num-1-beat-groups :accessor num-1-beat-groups :type integer :initform 0)
   ;; this envelope with ys from 0-10 indicates how often we should diverge from
   ;; the 1-beat rthms and insert a repeating (hammering) rthm instead.  This
   ;; will only be queried each time we insert a rest, rather than at every beat
   (sticking-curve :accessor sticking-curve :type list 
                   :initarg :sticking-curve :initform '(0 2 100 2))
   ;; how many slower-rthm bars to combine into a rthm-seq for one harmonic set
   (harmonic-rthm-curve :accessor harmonic-rthm-curve :type list
                        :initarg :harmonic-rthm-curve :initform '(0 2 100 2))
   ;; what beat are we working in: qs, es?
   (beat :accessor beat :type integer :initarg :beat 
         :initform 4)
   ;; whether we apply the sticking algorithm
   (do-sticking :accessor do-sticking :type boolean :initarg :do-sticking 
                :initform t)
   ;; whether we apply the rest algorithm
   (do-rests :accessor do-rests :type boolean :initarg :do-rests :initform t)
   ;; alternatively, envelopes to control whether we're sticking/resting or not
   ;; these should range from 0->1 and will be rounded when interpolating
   ;; they will only be active if do-sticking/do-rests is t
   (do-sticking-curve :accessor do-sticking-curve :type list :initarg
                      :do-sticking-curve :initform nil)
   (do-rests-curve :accessor do-rests-curve :type list :initarg :do-rests-curve
                   :initform nil)
   ;; the activity-levels instance that we'll use to decide whether to stick or
   ;; not.  This is called each time we generate a rest from rest-re (i.e. not
   ;; every beat)  
   (sticking-al :accessor sticking-al :initform (make-al))
   ;; generated at init if not given here NB a procession algorithm is created
   ;; from this list at init so it would be best to apply something similar (if
   ;; desired) if not accepting the default--in any case if a cscl is provided
   ;; it will be used instead of the default procession.
   (sticking-rthms :accessor sticking-rthms :initarg :sticking-rthms
                   :initform '(e e e. q e s))
   ;; when we stick, how many repeats do we have? when we've exhausted this
   ;; list we just start back at the beginning again.  NB we make a cscl
   ;; procession out of this at init, unless a cscl is provided.
   (sticking-repeats :accessor sticking-repeats :initarg :sticking-repeats
                     :initform '(3 5 3 5 8 13 21))
   ;; this gets queried every beat to see if we use a 1-beat rthm or insert a
   ;; rest
   (activity-curve :accessor activity-curve :type list 
                   :initarg :activity-curve :initform '(0 10 100 10))
   ;; the acivity-levels instance that will decide whether we use a 1-beat rthm
   ;; or not.
   (main-al :accessor main-al :initform (make-al))
   ;; the acivity-levels instance that will decide whether we use a slower rthm
   ;; or not.  NB although this shares the same activity curve as main-al it
   ;; starts with a different list (at the same level) so we'll not have both
   ;; voices resting/playing at the same time.
   (slower-al :accessor slower-al :initform (make-al 2))
   ;; a list of 2-beat and 3-beat bars; will be turned into a
   ;; rthm-chain-slow instance so NB that this will remain as lists of unparsed
   ;; rhythms.  
   (slower-rthms :accessor slower-rthms :type list :initarg :slower-rthms
                 :initform nil)
   ;; 19.1.11: the total number of slower bars we'll have in the chain NB this
   ;; depends not only on 1-beat-rthms but the activity curve so can only be
   ;; known after running rthm-chain-gen
   (num-slower-bars :accessor num-slower-bars :type integer :initform 0)
   ;; the instance created from slower-rthms
   (rcs :accessor rcs :initform nil)
   ;; There are three main pieces of data for rests: 1) the rests we'll use 2)
   ;; when rests will occur 3) what order they'll occur in.  rest-re determines
   ;; after how many 1-beat rhythms we'll insert a rest.  rest-cycle
   ;; determines which rests we'll insert from the rests list.
   (rests :accessor rests :type list :initarg :rests 
          :initform '(e q q. w))
   ;; the recurring-event data we'll use to insert the rests
   ;; data is something like '((2 3) (3 2) (5 3) (8 2)) which means every two
   ;; events three times, then every 3 events twice etc.
   (rest-re :accessor rest-re :initarg :rest-re 
            :initform '((2 3) (3 2) (2 2) (5 1) (3 3) (8 1)))
   ;; so, we'll alternate e,q,q.,w rests. this slot determines the order these
   ;; will occur in; first element of the pairs is the index into rests (above)
   ;; the second element is how many times it will occur.
   (rest-cycle :accessor rest-cycle :initarg :rest-cycle
               :initform '((0 3) (1 1) (0 2) (2 1) (1 1) (3 1)))
   ;; the number of rthm-seqs we generated i.e. in the palette and the map
   (num-rthm-seqs :accessor num-rthm-seqs :type integer :initform 0)
   ;; the rthm-seq-map needs an id (section name/number)
   (section-id :accessor section-id :initarg :section-id :initform 1)
   ;; the mix/max beat duration of bars generated; can be nil, whereupon bars
   ;; will not be split
   (split-data :accessor split-data :type list :initarg :split-data
               :initform '(2 5))
   ;; the algorithm will need to know how many beats we're to generate (not
   ;; including sticking points or rests)
   (num-beats :accessor num-beats :type integer :initarg :num-beats 
              :initform 0)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod initialize-instance :after ((rc rthm-chain) &rest initargs)
  (declare (ignore initargs))
  ;; otherwise we can't use references like '(1 pno-rh1)
  (setf (recurse-simple-data rc) nil 
        (rests rc) (loop for r in (rests rc) collect (make-rest r))
        (rest-re rc) (make-re (rest-re rc) :return-data (rests rc)
                              :return-data-cycle (rest-cycle rc))
        (num-1-beat-rthms rc) (length (first (1-beat-rthms rc)))
        (num-1-beat-groups rc) (length (1-beat-rthms rc))
        (1-beat-rthms rc) 
        (loop for group in (1-beat-rthms rc) do
             (unless (= (length group) (num-1-beat-rthms rc))
               (error "rthm-chain::init: Each group in 1-beat-rthms must ~
                       have the same number of beats ~%(here ~a): ~a"
                      (length group) group))
             collect
             (loop for beat in group collect
                  (make-rhythms beat (list 1 (beat rc))))))
  (when (slower-rthms rc)
    ;; just to trigger the setf method
    (setf (slower-rthms rc) (slower-rthms rc)))
  ;; all our curves need stretching to fit the number of beats we're going to
  ;; generate 
  (fit-curves rc)
  (unless (cscl-p (sticking-rthms rc))
    (setf (sticking-rthms rc)
          (make-cscl
           (procession 
            20
            (loop for r in (sticking-rthms rc) collect
                 (make-rhythm r))
            :peak 1 :expt 5))))
  (unless (cscl-p (sticking-repeats rc))
    (setf (sticking-repeats rc)
          ;; this abuses the procession function a little by repeating elements
          ;; but it gives us what we want (mainly 3s and 5s, some 8s, a couple
          ;; of 13s and one 21. 
          (make-cscl
           (procession 55 (sticking-repeats rc)
                       :peak 1 :expt 5))))
  (unless (zerop (num-beats rc))
    (rthm-chain-gen rc :rests (do-rests rc) :stick (do-sticking rc) 
                    :use-fibonacci (1-beat-fibonacci rc)
                    :section-id (section-id rc)
                    :num-beats (num-beats rc))
    (when (split-data rc)
      (split rc :min-beats (first (split-data rc)) 
             :max-beats (second (split-data rc))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#|
;;; MDE Sat Apr 28 13:14:08 2012 -- as we can call add-voice this limit of 2
;;; players is no longer valid
;;; MDE Sat Apr 28 12:47:20 2012
(defmethod verify-and-store :after ((rc rthm-chain))
  ;; allow no players so we can clone
  (when (players rc)
    (unless (= 2 (length (players rc)))
      (error "rthm-chain::verify-and-store: there can only be two players: ~a"
             (players rc)))))
|#

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Sat Apr 28 11:49:47 2012 
(defmethod clone ((rc rthm-chain))
  (clone-with-new-class rc 'rthm-chain))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Sat Apr 28 11:49:50 2012 

(defmethod clone-with-new-class :around ((rc rthm-chain) new-class)
  (declare (ignore new-class))
  (let ((rsm (call-next-method)))
    (when (rthm-chain-p rsm)
      (setf (slot-value rsm '1-beat-rthms) (my-copy-list (1-beat-rthms rc))
            (slot-value rsm '1-beat-fibonacci) (1-beat-fibonacci rc)
            (slot-value rsm 'slow-fibonacci) (slow-fibonacci rc)
            (slot-value rsm 'num-1-beat-rthms) (num-1-beat-rthms rc)
            (slot-value rsm 'num-1-beat-groups) (num-1-beat-groups rc)
            (slot-value rsm 'sticking-curve) (copy-list (sticking-curve rc))
            (slot-value rsm 'harmonic-rthm-curve)
            (copy-list (harmonic-rthm-curve rc))
            (slot-value rsm 'harmonic-rthm-curve) (harmonic-rthm-curve rc)
            (slot-value rsm 'beat) (beat rc)
            (slot-value rsm 'do-sticking) (do-sticking rc)
            (slot-value rsm 'do-rests) (do-rests rc)
            (slot-value rsm 'do-sticking-curve)
            (copy-list (do-sticking-curve rc))
            (slot-value rsm 'do-rests-curve) (copy-list (do-rests-curve rc))
            (slot-value rsm 'sticking-al) (clone (sticking-al rc))
            (slot-value rsm 'sticking-rthms) (clone (sticking-rthms rc))
            (slot-value rsm 'sticking-repeats) (clone (sticking-repeats rc))
            (slot-value rsm 'activity-curve) (copy-list (activity-curve rc))
            (slot-value rsm 'main-al) (clone (main-al rc))
            (slot-value rsm 'slower-al) (clone (slower-al rc))
            (slot-value rsm 'slower-rthms) (my-copy-list (slower-rthms rc))
            (slot-value rsm 'num-slower-bars) (num-slower-bars rc)
            (slot-value rsm 'rcs) (clone (rcs rc))
            (slot-value rsm 'rests) (my-copy-list (rests rc))
            (slot-value rsm 'rest-re) (clone (rest-re rc))
            (slot-value rsm 'rest-cycle) (copy-list (rest-cycle rc))
            (slot-value rsm 'num-rthm-seqs) (num-rthm-seqs rc)
            (slot-value rsm 'section-id) (section-id rc)
            (slot-value rsm 'split-data) (copy-list (split-data rc))
            (slot-value rsm 'num-beats) (num-beats rc))
      (verify-and-store rsm))
    rsm))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; MDE Sat Apr 28 11:22:19 2012
(defmethod print-object :before ((rc rthm-chain) stream)
  (format stream "~&RTHM-CHAIN: 1-beat-rthms: ~a~
                  ~%            slower-rthms: ~a~
                  ~%            1-beat-fibonacci: ~a~
                  ~%            num-beats: ~a~
                  ~%            slow-fibonacci: ~a~
                  ~%            num-1-beat-rthms: ~a~
                  ~%            num-1-beat-groups: ~a~
                  ~%            sticking-curve: ~a~
                  ~%            harmonic-rthm-curve: ~a~
                  ~%            beat: ~a~
                  ~%            do-sticking: ~a~
                  ~%            do-rests: ~a~
                  ~%            do-sticking-curve: ~a~
                  ~%            do-rests-curve: ~a~
                  ~%            sticking-al: (not printed for brevity's sake)~
                  ~%            sticking-rthms: ~a~
                  ~%            sticking-repeats: ~a~
                  ~%            activity-curve: ~a~
                  ~%            main-al: (not printed for brevity's sake)~
                  ~%            slower-al: (not printed for brevity's sake)~
                  ~%            num-slower-bars: ~a~
                  ~%            rcs: (not printed for brevity's sake)~
                  ~%            rests: ~a~
                  ~%            rest-re: (not printed for brevity's sake)~
                  ~%            rest-cycle: ~a~
                  ~%            num-rthm-seqs: ~a~
                  ~%            section-id: ~a~
                  ~%            split-data: ~a"
          (loop for l in (1-beat-rthms rc) collect
               (loop for sl in l collect
                    (rhythms-as-symbols sl)))
          (slower-rthms rc) (1-beat-fibonacci rc) (num-beats rc)
          (slow-fibonacci rc) (num-1-beat-rthms rc) (num-1-beat-groups rc)
          (sticking-curve rc) (harmonic-rthm-curve rc) (beat rc) 
          (do-sticking rc) (do-rests rc) (do-sticking-curve rc)
          (do-rests-curve rc) 
          (loop for r in (data (sticking-rthms rc)) collect (data r))
          (data (sticking-repeats rc)) (activity-curve rc) 
          (num-slower-bars rc) (rhythms-as-symbols (rests rc))
          (rest-cycle rc) (num-rthm-seqs rc) (section-id rc) 
          (split-data rc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  29.1.11: split the longer bars into smaller ones where possible.  we
;;; know that the slower and faster rthm-seqs are stuffed into the palette
;;; one after the other so it's safe to loop through them pairwise (but check
;;; rthm-seq ids are what they're expected to be)

;;; ****m* rthm-chain/split
;;; FUNCTION
;;; 
;;; 
;;; ARGUMENTS
;;; 
;;; 
;;; OPTIONAL ARGUMENTS
;;; 
;;; 
;;; RETURN VALUE
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defmethod split ((rc rthm-chain) &key
                  (min-beats 2) (max-beats 5) warn (clone t))
;;; ****
  (flet ((got-stick-rthm (1-beat-rs slower-rs)
           ;; sticking rthms have ids like STICK-RTHMS-AUTO5 and
           ;; STICK-RTHMS-AUTO-SLOW5
           ;;(unless (string= (id 1-beat-name)
           (let ((slow-string (string (id slower-rs))))
             (and (> (length slow-string) 20)
                  (string= (string (id 1-beat-rs)) "STICK-RTHMS-AUTO"
                           :end1 16)
                  (string= slow-string "STICK-RTHMS-AUTO-SLOW" :end1 21)))))
    (let* ((rthm-seqs (data (get-data-data (section-id rc) (palette rc)))) ;list
           (1-beat-player (first (players rc)))
           (rs-main-count 1)
           (slower-player (second (players rc)))
           (new-rss
            (loop with got-stick = nil
               for 1-beat-rs in rthm-seqs by #'cddr
               for slower-rs in (cdr rthm-seqs) by #'cddr
               for 1-beat-name = (rthm-chain-seq-name 1-beat-player
                                                      rs-main-count)
               for slower-name = (rthm-chain-seq-name slower-player
                                                      rs-main-count)
               do
               ;; NB it's important this setf comes first so it's run every time
               (unless (or (setf got-stick (got-stick-rthm 1-beat-rs slower-rs))
                           (and (eq 1-beat-name (id 1-beat-rs))
                                (eq slower-name (id slower-rs))))
                 (error "rthm-chain::split: unexpected rthm-seq names.~
                        ~%Expected ~a and ~a but got ~a and ~a"
                        1-beat-name slower-name (id 1-beat-rs) (id slower-rs)))
               (unless got-stick
                 (incf rs-main-count))
               ;; (format t "~&before split")
               ;; (print-simple 1-beat-rs)
               ;; (print-simple slower-rs)
               ;; 28.1.11 split the slower-rs (potentially harder to split)
               ;; then use its new metrical structure with the 1-beat-rs
               (let* ((rs-split (split slower-rs :min-beats min-beats
                                       :max-beats max-beats :warn warn
                                       :clone clone))
                      ;; if we can't split, we return the unaltered
                      ;; rthm-seq, but if adopt-meters fails, it returns
                      ;; nil 
                      (rs-adopt (adopt-meters 1-beat-rs rs-split
                                              :is-full-error nil)))
                 (if rs-adopt
                     (progn
                       ;; (print 'bingo1)
                       (setf slower-rs rs-split
                             1-beat-rs rs-adopt))
                     ;; if that didn't work, try it the other way around
                     (progn 
                       (setf rs-split (split 1-beat-rs :min-beats min-beats
                                             :max-beats max-beats)
                             rs-adopt (adopt-meters slower-rs rs-split
                                                    :is-full-error nil))
                       (when rs-adopt
                         ;; (print 'bingo2)
                         (setf slower-rs rs-adopt
                               1-beat-rs rs-split)))))
               ;;(format t "~&after split")
               ;; (print-simple 1-beat-rs)
               ;; (print-simple slower-rs)
               collect 1-beat-rs
               collect slower-rs)))
      (setf (data (get-data-data (section-id rc) (palette rc))) new-rss)
      t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod fit-curves ((rc rthm-chain) &optional num-beats)
  (let ((lastx (1- (if num-beats 
                       num-beats
                       (num-beats rc)))))
    (setf (sticking-curve rc) (new-lastx (sticking-curve rc) lastx)
          (harmonic-rthm-curve rc) (new-lastx (harmonic-rthm-curve rc) lastx)
          (activity-curve rc) (new-lastx (activity-curve rc) lastx))
    (when (do-sticking-curve rc)
      (setf (do-sticking-curve rc) (new-lastx (do-sticking-curve rc) lastx)))
    (when (do-rests-curve rc)
      (setf (do-rests-curve rc) (new-lastx (do-rests-curve rc) lastx)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* rthm-chain/reset
;;; FUNCTION
;;; 
;;; 
;;; ARGUMENTS
;;; 
;;; 
;;; OPTIONAL ARGUMENTS
;;; 
;;; 
;;; RETURN VALUE
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defmethod reset ((rc rthm-chain) &optional where)
;;; ****
  (declare (ignore where))
  (stick-rthms nil nil) ;; reset count
  (reset (sticking-al rc))
  (reset (main-al rc))
  (reset (slower-al rc))
  ;; the slower-rthms object
  (when (rcs rc)
    (reset (rcs rc)))
  (when (sticking-repeats rc)
    (reset (sticking-repeats rc)))
  (when (sticking-rthms rc)
    (reset (sticking-rthms rc))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; call this after every beat to get a nil (no rest) or the rest rhythm to
;;; insert.

(defmethod rc-rest ((rc rthm-chain))
  (get-it (rest-re rc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; call this every time we've just inserted a rest: if we're going to stick it
;;; will return a rthm and the number of times it is to be repeat, otherwise nil

(defmethod stick ((rc rthm-chain) beat-num)
  (let ((stick-level (interpolate beat-num (sticking-curve rc) :warn nil)))
    (when (active (sticking-al rc) stick-level)
      (let ((rthm (get-next (sticking-rthms rc)))
            (repeats (get-next (sticking-repeats rc))))
        (values rthm repeats)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; SAR Mon Apr 30 11:29:17 BST 2012: Conforming robodoc entry

;;; ****m* rthm-chain/rthm-chain-gen
;;; FUNCTION

;;; Generate a chain of rhythms, also internally making use of the procession
;;; function. 

;;; The basic algorithm for 2 parts is: we're given an arbitrary number of
;;; 1-beat rthms (e.g. s s (e)) and 2-3 beat slower-moving counterpoints.  We
;;; generate a sequence of these using the procession function.  Then we apply
;;; the activity curve, and after that the insertion of 8th rests.  Then come
;;; the 'sticking points': these come after the rests and the activity curves
;;; applied to these count inserted rests not seqs or beats.
;;; 
;;; NB: Rests are put into the rthm-seq mid-sequence so sticking points won't
;;;     come straight after the rests, rather, at the end of the seq.
;;; 
;;; The activity curves that turn notes into rests will be queried every beat
;;; so if we change an activity level we don't wait until the end of the
;;; previous level's ten beats.
;;; 
;;; NB: This method is not generally called by the user (though it can be of
;;;     course), rather it's called by the init function.
;;; 
;;; ARGUMENTS 
;;; - A rthm-chain object.
;;;
;;; OPTIONAL ARGUMENTS
;;; keyword arguments:
;;; - (key :rests ) whether to generate the rests default: t
;;; - (key :stick)  whether to generate the sticking point s
;;; - (key :num-beats ) how many beats to use for the
;;;    algorithm. NB we'll generate considerably more if we have sticking and
;;;    rests; this number really just refers to the number of standard 1-beat
;;;    rhythms we'll generate.  If nil, then we use the num-beats slot of the
;;;    rc instance. default: nil
;;; - (key :use-fibonacci ) whether to use a fibonacci transition to
;;;    move through the 1-beat rhythms (so they'll be repeated) or the
;;;    procession algorithm (where they'll be alternated). default t
;;; - (key :section-id ) for the sake of the map, what section we'll
;;;    put the references into.  The rthm-seqs themselves will be parcelled up
;;;    into an object with this id too, so we can avoid id conflicts if we
;;;    combine 2+ sections generatd by separate rthm-chain objects. default 1
;;; - (key :split ): whether to split up longer generated bars
;;;   (e.g. 7/4) into smaller bars.  If this is a two-element list it
;;;    represents the min/max number of beats in a bar (where a 6/8 bar is two
;;;    compound beats) default '(2 5)
;;; - (key :wrap ): when we create the 1-beat rythms' and slow
;;;    rhythms' order, we can choose to start at any point in the list default nil
;;; 
;;; RETURN VALUE  
;;; the number of rthm-seqs we've generated
;;; 
;;; SYNOPSIS
(defmethod rthm-chain-gen ((rc rthm-chain)
                           &key
                           (use-fibonacci t) 
                           (rests t)
                           (stick t)
                           (section-id 1)
                           num-beats
                           wrap)
;;; ****
  ;; 19.1.11 we call the algorithm twice, the first time just to find out how
  ;; many slower bars we'll have, the 2nd time to use this number to get the
  ;; transition between the groups right.
  (rthm-chain-gen-aux rc use-fibonacci rests stick section-id num-beats
                      wrap)
  (rthm-chain-gen-aux rc use-fibonacci rests stick section-id num-beats
                      wrap))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod rthm-chain-gen-aux ((rc rthm-chain) use-fibonacci rests stick
                               section-id num-beats wrap)
  ;; usually the number of beats is given at object init but it can be passed
  ;; here too
  (if num-beats
      ;; NB this will auto-call fit-curves
      (setf (num-beats rc) num-beats)
      ;; otherwise use the one we got at init
      (setf num-beats (num-beats rc)))
  ;; delete all from the palette; the map is re-generated when we setf the data
  ;; slot at the end.  Can't use normal setf as that would mean palette/map
  ;; refs would be checked,
  (setf (slot-value rc 'palette) 
        (let ((rsp (make-rsp 'rthm-chain-rsp nil)))
          (add-empty-parcel rsp section-id 'rthm-seq-palette)
          rsp))
  (reset rc)
  ;; get the procession (as a cscl) we'll need for the 1-beat rthms using
  ;; num-beats as arg 
  (let ((1beatp (rthm-chain-get-order 
                 num-beats (length (first (1-beat-rthms rc)))
                 '1beatp use-fibonacci wrap))
        ;; now get the transition from 1 group of 1-beat rthms to the other(s)
        (rthms-transition (make-cscl (fibonacci-transitions 
                                      num-beats (length (1-beat-rthms rc)))
                                     :id 'rthms-transition))
        (1-beat-rest (make-rest (beat rc)))
        (rs-count 0)
        ;; we have to count in rs-count the total number of rthm-seqs but to
        ;; count the main (rthm-chain) seqs we need a separate counter so as
        ;; not to skip numbers when naming them and we hit a sticking point
        (rs-main-count 0)
        (slower-bars '())
        (beat-count 0)
        (slower-bar-count 0)
        (1-beat-bar '())
        (1-beat-bars '())
        (meters '())
        (slower-beats 0)
        slower-rthms
        (1-beat-player (if (players rc)
                           (first (players rc))
                           '1beat))
        (slower-player (if (players rc)
                           (second (players rc))
                           'slower))
        activity-level
        (do-sticking-curve-val t)
        (do-rests-curve-val t)
        1-beat-active 
        slower-active
        rest
        stick-fast-id stick-slow-id
        (1-beat-map '())
        (slower-map '())
        (harmonic-rthm 0))
    (labels ((process-meter (meter)
               (let ((m2 (* 2 meter)))
                 (cond ((whole-num-p meter) (list (floor meter) (beat rc)))
                       ((whole-num-p m2) (list (floor m2) (* 2 (beat rc))))
                       (t (error "rthm-chain::rthm-chain-gen: bad meter: ~a"
                                 meter)))))
             (process-bars (bars meters id)
               (make-instance 'rthm-seq :id id :data
                              (list
                               ;; bars are just simple lists of rhythms
                               (loop for bar in bars and meter in meters
                                  with last-meter = -1
                                  collect 
                                  (if (= meter last-meter)
                                      bar
                                      `(,(process-meter meter) ,@bar))
                                  do (setf last-meter meter)))))
             (save-1-beat ()
               (when 1-beat-bar
                 (push (my-copy-list 1-beat-bar) 1-beat-bars)
                 (setf 1-beat-bar '())))
             (save-em ()
               ;; NB both slower-bars and 1-beat-bars are a list of bars each
               ;; of which is a list of beats containing rhythms
               (when slower-bars        ; we'll always have 1-beat-bars too
                 ;; gen the rthm-seqs (slow and 1-beat), put 'em in the rsp,
                 ;; and put the refs in the mpa
                 (incf rs-count)
                 (incf rs-main-count)
                 ;; if we were given a list of players use those names 
                 (let ((1-beat-id (rthm-chain-seq-name 1-beat-player 
                                                       rs-main-count))
                       (slower-id (rthm-chain-seq-name slower-player
                                                       rs-main-count))
                       1-beat-rs slower-rs)
                   (save-1-beat)
                   (setf 1-beat-bars (loop for bar in (nreverse 1-beat-bars)
                                        collect 
                                        (loop for beat in (nreverse bar)
                                           appending beat
                                           do (incf beat-count)))
                         ;; slower-bars (nreverse slower-bars)
                         slower-bars (loop for bar in (nreverse slower-bars)
                                        collect 
                                        ;; unlike the 1-beat-bars, where the
                                        ;; beats are pushed in, the beats are
                                        ;; in the right order here
                                        (loop for beat in bar
                                           appending beat))
                         meters (nreverse meters)
                         ;; here's where we make the rthm-seqs
                         1-beat-rs (process-bars 1-beat-bars meters 1-beat-id)
                         slower-rs (process-bars slower-bars meters slower-id)
                         1-beat-bars '()
                         meters '()
                         slower-bars '())
                   ;; NB if the order or anything else is changed here we'll
                   ;; have to change the split method too.
                   (add 1-beat-rs (palette rc) section-id)
                   (add slower-rs (palette rc) section-id)
                   ;; here's where we add the rthm-seq refs to the maps
                   (push (list section-id 1-beat-id) 1-beat-map)
                   (push (list section-id slower-id) slower-map)
                   (when stick-slow-id  ; stick-fast-id will be non-nil too
                     (incf rs-count)
                     (push (list section-id stick-fast-id) 1-beat-map)
                     (push (list section-id stick-slow-id) slower-map)
                     (setf stick-fast-id nil
                           stick-slow-id nil))))))
      ;; get the processions we'll need for the slower-rthms; this is handled
      ;; in the rthm-chain-slow class automatically.  NB 19.1.11 as we now run
      ;; this algorithm twice, use the num-beats first of all, then, when we
      ;; know how many slower-bars will be generated, use that to get the
      ;; proper transition
      (init-order (rcs rc)
                  (if (zerop (num-slower-bars rc))
                      num-beats
                      (num-slower-bars rc))
                  (slow-fibonacci rc)
                  wrap)
      (loop with i = 0 do 
         ;; if we haven't got a slower-rthm bar, get one now (after storing what
         ;; we have generated in a bar, the meter of which is determined by the
         ;; current-beats slot of the slower-rthms (rc::rcs slot)
           (setf activity-level (interpolate i (activity-curve rc) :warn nil)
                 1-beat-active (active (main-al rc) activity-level)
                 slower-active (active (slower-al rc) activity-level))
           (when (do-sticking-curve rc)
             (setf do-sticking-curve-val 
                   (not (zerop (round (interpolate i (do-sticking-curve rc)
                                                   :warn nil))))))
           (when (do-rests-curve rc)
             (setf do-rests-curve-val 
                   (not (zerop (round (interpolate i (do-rests-curve rc)
                                                   :warn nil))))))
           (when (zerop slower-beats)
             (if (zerop harmonic-rthm)
                 (progn
                   ;; quit when we've got at least num-beats worth and we've
                   ;; got all the beats we need for this rthm-seq  
                   (when (>= i (num-beats rc))
                     (loop-finish))
                   ;; get the harmonic-rthm number: this specifies how many
                   ;; slower-rthms make up a rthm-seq; when the harmonic-rthm =
                   ;; 0, we generate the 1-beat and slower rthm-seqs and add
                   ;; their references to the map, then get the next
                   ;; harmonic-rthm using the current beat as index.
                   ;; harmonic-rthm will be decremented each time we use a
                   ;; slower-rthm up
                   (setf harmonic-rthm 
                         (1- (round (interpolate i (harmonic-rthm-curve rc)
                                                 :warn nil))))
                   ;; put the slower and 1-beat rthms in the palette and map
                   (save-em))
                 (decf harmonic-rthm))
             ;; get-next returns a list of rhythm objects and will update the
             ;; rcs current-beats slot; this tells us how many beats are in
             ;; this bar 
             ;; 23.1.11 if we want more than 2 voices, get-next must return
             ;; more rhythms, as a list
             (setf slower-rthms (get-next (rcs rc))
                   ;; either 2 or 3
                   slower-beats (current-beats (rcs rc)))
             (save-1-beat)
             (push slower-beats meters)
             (incf slower-bar-count)
             (unless slower-active
               (setf slower-rthms 
                     (loop for beat in slower-rthms collect
                          (force-rests beat t)))) ; clone 'em ;
             (push slower-rthms slower-bars))
           (decf slower-beats)
         ;; if we've got 1-beat activity here (main-al) collect the rthms
         ;; associated with the next in the 1-beat-procession. then see if
         ;; we've got to insert a rest here. if so we see if we're going to
         ;; stick too: sticking implies a new rthm-seq (hence harmony) and a new
         ;; slower-rthm (which will be repeated until the sticking stops).
           (push 
            (if 1-beat-active
                ;; 23.1.11 if more than 2 voices need to get more
                (let ((1br (nth (1- (get-next 1beatp)) ; the procession
                                (nth (get-next rthms-transition) ; transition
                                     (1-beat-rthms rc)))))
                  (unless 1br
                    (error "rthm-chain::rthm-chain-gen: no 1-beat-rthm."))
                  (incf i)
                  1br)
                (list (clone 1-beat-rest)))
            ;; don't forget: this is a whole bar of 1-beat rthms
            1-beat-bar)
         ;; insert a rest?
           (when (setf rest (rc-rest rc))
             (let ((rest-beats (/ (duration rest) (duration 1-beat-rest)))
                   (nth-beat (1- (- (current-beats (rcs rc)) slower-beats))))
               ;; (format t "~&rest: ~a" rest-beats)
               (when (and rests do-rests-curve-val)
                 (incf (first meters) rest-beats)
                 ;; the rest has to be a list because a beat is a list of
                 ;; rhythms 
                 ;; 23.1.11 must push this in for each voice
                 (push (list (clone rest)) 1-beat-bar)
                 ;; got to handle possible ties
                 (when (and (> nth-beat 0)
                            (is-tied-from 
                             (first (last (nth (1- nth-beat)
                                               (first slower-bars))))))
                   ;; 23.1.11 must do this for each slower voice
                   (setf (is-tied-from (first (last (nth (1- nth-beat)
                                                         (first slower-bars)))))
                         nil)
                   (force-rest (first (nth nth-beat 
                                           (first slower-bars))))
                   (loop for n in (rest (nth nth-beat (first slower-bars)))
                      do (delete-beam n)))
                 (setf (first slower-bars)
                       (splice (list (list (clone rest))) 
                               (first slower-bars) 
                               nth-beat)))
               ;; stick after this rest?  but don't try to do more than 1 stick
               ;; for each rthm-seq
               (unless stick-fast-id 
                 (when (and stick do-sticking-curve-val)
                   ;; (print 'here)
                   (multiple-value-bind
                         (rthm repeats)
                       (stick rc i)
                     (when rthm
                       ;; (incf rs-count)
                       (multiple-value-bind 
                             (sfast sslow)
                           (stick-rthms rthm repeats)
                         (add sfast (palette rc) section-id)
                         (add sslow (palette rc) section-id)
                         ;; can't push them into the maps here otherwise the
                         ;; sticks will come before the normal rthm-seqs instead
                         ;; of after 
                         (setf stick-fast-id (id sfast)
                               stick-slow-id (id sslow))))))))))
      (save-em)
      ;; now generate the rthm-seq-map data
      (setf 1-beat-map (reverse 1-beat-map)
            slower-map (reverse slower-map)
            ;; this will alter the players slot but it should result in the
            ;; same list actually
            ;; NB this doesn't work unless we've had sticking
            (data rc) `((,section-id ((,1-beat-player ,1-beat-map)
                                      (,slower-player ,slower-map))))
            (num-slower-bars rc) slower-bar-count
            (num-rthm-seqs rc) rs-count))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* rthm-chain/add-voice
;;; FUNCTION
;;; 
;;; The main rthm-chain algorithm generates only two voices.  Rather than
;;; generate further voices in the same fashion, use the already created
;;; rthm-seqs to create other voices.  The challenge here is that each rthm-seq
;;; has potentially its own time signature structure: there could be a 2/4 bar
;;; followed by 5/4 then 3/16; or any other combination of any meter.  So first
;;; of all, we analyse the time-signature structure of the existing rthm-seqs
;;; and save those with the same bar/meter structure together in the order in
;;; which they occurred.  When creating the extra voice then, we actually start
;;; ahead of the main voice, by choosing <offset> similar rthm-seqs in advance
;;; 
;;; ARGUMENTS 
;;; - the rthm-chain instance
;;; - the parent voice i.e. a reference into the create rthm-seq-map (e.g. '(1
;;; perc1) 
;;; - the id of the new player (symbol)
;;; - (optional: offset default 1): which similar rthm-seq to start at (so
;;; generated voice will be ahead of main voice)
;;; 
;;; RETURN VALUE  
;;; t
;;; 
;;; EXAMPLE
;;; 
;;; DATE
;;; 
;;; SYNOPSIS
(defmethod add-voice ((rc rthm-chain) parent new-player &optional (offset 1))
;;; ****
  (let* ((tsr (get-time-sig-ral rc (palette rc)))
         (player-tsr (get-data parent tsr))
         (new-refs '()))
    ;; reset the cscl to start at <offset>
    (loop for cscl in (data player-tsr) do 
         (reset cscl (if (< offset (sclist-length cscl))
                         offset
                         (1- (sclist-length cscl)))))
    (setf new-refs
          (loop for parent-rthm-seq-ref in (get-data-data parent rc) 
             for parent-rthm-seq = (get-data parent-rthm-seq-ref (palette rc))
             for parent-tss = (get-data (get-time-sigs-tag parent-rthm-seq) 
                                        player-tsr)
             ;; collect (list parent-rthm-seq-ref (get-next parent-tss))))
             collect (get-next parent-tss)))
    (add (make-named-object new-player new-refs) 
         (get-data-data (butlast parent) rc))
    (push new-player (players rc))
    (incf (num-players rc))
    (relink-named-objects rc)
    t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod (setf num-beats) :after (num (rc rthm-chain))
  (declare (ignore num))
  (fit-curves rc))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod (setf slower-rthms) :after (rthms (rc rthm-chain))
  (unless (= 2 (length rthms))
    (error "rthm-chain::init: slower rthms must be a ~
            2-element list of rhythms (2 beats then 3 beats): ~%~a"
           rthms))
  (setf (rcs rc)
        (make-instance 'rthm-chain-slow
                       :beat (beat rc)
                       :2beat (first rthms)
                       :3beat (second rthms))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Related functions.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Sat Apr 28 10:05:43 2012 
;;; SAR Mon Apr 30 11:20:15 BST 2012: Added robodoc entry
;;; SAR Tue May  8 12:21:04 BST 2012: Re-visited robodoc entry

;;; ****f* rthm-chain/make-rthm-chain
;;; FUNCTION
;;; Create an instance of a rthm-chain object. The rthm-chain class enables
;;; the algorithmic generation of a rthm-seq-map and its associated
;;; rthm-seq-palette, which consists in turn of algorithmically generated
;;; rthm-seq objects. 
;;;
;;; The rhythm-seq objects are made up of both faster material based on 1-beat
;;; groups and slower-moving counterpoint based on 2- or 3-beat groups.
;;;
;;; The rthm-chain class also allows for control of the degree of activity in
;;; the parts over time through user-specified envelopes.
;;;
;;; Rests are automatically inserted at regular but changing intervals.
;;;
;;; Specified 'sticking points' cause individual rhythms to be repeated a
;;; certain number of times. Sticking happens after rests and can also be
;;; controlled with an activity envelope. 
;;;
;;; NB: Because this method uses the procession method internally, each
;;;     collection of 1-beat-rthms and slower-rthms defined must contain at
;;;     least four items.
;;;
;;; NB: Since this method automatically inserts rests into the chains, the user
;;;     may like to implement the various tie-over-rests post-generation
;;;     editing methods. If this is done, the handle-ties method may also be
;;;     recommended, as the tie-over-rests methods only affect printed output
;;;     and not MIDI output.
;;;
;;; ARGUMENTS
;;; - A number, symbol, or string that is to be the ID of the new rthm-chain
;;;   object. 
;;; - An integer that is the number of beats to be generated prior to adding
;;;   additional material created from sticking points and the automatic
;;;   addition of rests.
;;; - A list with sublists of rhythms that are to be the 1-beat rhythms used to
;;;   construct the faster-moving material of the rthm-seq-palette. Each
;;;   sublist represents the repertoire of rhythms that will be used by the
;;;   procession method. Each sublist must contain the same number of rthms but
;;;   their number and the number of sublists is open. A transition will be
;;;   made from one group of rhythms to the next over the whole output
;;;   (i.e. not one unit to another within e.g. the 1-beat rhythms) according
;;;   to a fibonacci-transition method.
;;; - A list with sublists of 2-beat and 3-beat full bars of rhythms used to
;;;   construct the slower-moving counterpoint material of the
;;;   rthm-seq-palette. This will be turned into a rthm-chain-slow object, and
;;;   will therefore remain as lists of unparsed rhythms. Each sublist must
;;;   contain the same number of rthms but their number and the number of
;;;   sublists is open. A transition will be made from one group of rhythms to
;;;   the next over the whole output (i.e. not one unit to another within
;;;   e.g. the 1-beat rhythms) according to a fibonacci-transition method. 
;;;   NB: The rhythm units of slower-rthms must be expressed in single beats;
;;;   e.g., a 2/4 bar must consist of q+q rather than h. The consolidate-notes
;;;   method can be called afterwards if desired.
;;; 
;;; OPTIONAL ARGUMENTS
;;; keyword arguments:
;;; - :beat. An integer that indicates the rhythmic unit of the primary beat
;;;   basis of the rhythms specified. Default = 4.
;;; - :1-beat-fibonacci. T or NIL to indicate whether the sequence of 1-beat
;;;   rhythms is to be generated using the fibonacci-transitions method or the
;;;   processions method. T = use fibonacci-transitions method. Default = NIL.
;;; - :slow-fibonacci. T or NIL to indicate whether the sequence of the slow
;;;   rhythms will be generated using the fibonacci-transitions method or the
;;;   processions method. This affects the order in which each 2- or 3-beat
;;;   unit is used when necessary, not the order in which each 2- or 3-beat
;;;   unit is selected; the latter is decided by the next element in the DATA
;;;   slot of the rthm-chain-slow object, which simply cycles through 
;;;   '(2 3 2 2 3 2 2 3 3 3). T = use fibonacci-transisitions method.
;;;   Default = NIL.
;;; - :players. A list of player IDs. When used in conjunction with a
;;;   slippery-chicken object (which is the standard usage), these must be IDs
;;;   as they are defined in that object's ENSEMBLE slot. 
;;;   Default = '(player1 player2).

;;; - :section-id. 

;; the rthm-seq-map needs an id (section
;;;   name/number). Default = 1. 

;;; - :rests. The rhythmic duration unit(s) of the rests that will be used when
;;;   the method uses the rest-insertion algorithm to automatically insert
;;;   rests into the resulting objects. The specified rests are used in a
;;;   sequence determined by a recurring-event object. Default = '(e q q. w).
;;; - :do-rests. T or NIL to indicate whether to apply the automatic
;;;   rest-insertion algorithm. T = use. Default = T.

;;; - :do-rests-curve. Default = NIL.

;;; - :rest-re. A list of 2-item lists that indicate the pattern by which rests
;;;   will be automatically inserted. The first number of each pair determines
;;;   how many events occur before inserting a rest, and the second number of
;;;   each pair determines how many times that interval will be repeated. For
;;;   example, (2 3) indicates that a rest will be inserted every two events,
;;;   three times in a row. The list passed here will be treated as data for a
;;;   recurring-event object that will be repeatedly cycled through. 
;;;   Default = '((2 3) (3 2) (2 2) (5 1) (3 3) (8 1)).

;;; - :rest-cycle. A list of 2-item lists that indicate the pattern by which
;;;   rests of specific rhythmic durations will be selected from the RESTS slot
;;;   for automatic insertion. The first number of each pair is a 0-based
;;;   position referring to the list of rests in the RESTS slot, and the second
;;;   number is the number of times the rest at that particular position should
;;;   be inserted. (This number does not mean that the selected rest will be
;;;   inserted that many times at once, but rather that each consecutive time
;;;   the rest algorithm selects one rest to be inserted, it will insert that
;;;   specific rest, for the specified number of consecutive times.) For
;;;   example, (0 3) indicates that for the next three times that the rest
;;;   algorithm selects one rest to insert, it will select the rest located at
;;;   position 0 in the list of rests in the RESTS slot (e by default).
;;;   Default ='((0 3) (1 1) (0 2) (2 1) (1 1) (3 1)).

;; so, we'll alternate e,q,q.,w rests. this slot determines the order these
   ;; will occur in; first element of the pairs is the index into rests (above)
   ;; the second element is how many times it will occur.

  ;; rest-cycle determines which rests we'll insert from the rests list.

;;; - :activity-curve.  In order to make music that 'progresses' we have curves
;;;                   with y values from 1-10 indicating how much activity
;;;                   there should be: 1 would mean only 1 in 10 beats would
;;;                   have notes in/on them, 10 would indicate that all do.  We
;;;                   use the patterns given in activity-levels::init-instance
;;;                   below, where 1 means 'play', 0 means 'rest'.  There are
;;;                   three examples of each level so that if we stick on one
;;;                   level of activity for some time we won't always get the
;;;                   same pattern: these will instead be cycled through.

;;; -if the activity curve indicates a rest for a slower-rhythms group, then
;;;                   the whole 2-3 beat group is omitted.

;;; - :sticking-curve. ;;; Sticking happens after rests.  This can be
;;;                   controlled with an activity envelope too, also indicating
;;;                   one of the 10 patterns above (but also including 0).  A 0
;;;                   or 1 unit here would refer to a certain number of repeats
;;;                   (1) or none (0).  How many repeats could be determined by
;;;                   something like: (procession 34 '(2 3 5 8 13) :peak 1
;;;                   :expt 3) There's always a slower group to accompany the
;;;                   sticking points: simply the next in the sequence,
;;;                   repeated for as long as we stick


;;; - :harmonic-rthm-curve.

;;;                   The harmonic-rthm curve specifies how many slower-rthms
;;;                   will be combined into a rthm-seq (each rthm-seq has a
;;;                   single harmony).  The default is 2 bars (slower-rthms)
;;;                   per rthm-seq.

;;; - :do-sticking. ;; whether we apply the sticking algorithm

;;; - :do-sticking-curve.    ;; alternatively, envelopes to control whether we're sticking/resting or not
   ;; these should range from 0->1 and will be rounded when interpolating
   ;; they will only be active if do-sticking/do-rests is t

;;; - :sticking-repeats.    ;; when we stick, how many repeats do we have? when we've exhausted this
   ;; list we just start back at the beginning again.  NB we make a cscl
   ;; procession out of this at init, unless a cscl is provided.

;;; - :sticking-rthms.    ;; generated at init if not given here NB a procession algorithm is created
   ;; from this list at init so it would be best to apply something similar (if
   ;; desired) if not accepting the default--in any case if a cscl is provided
   ;; it will be used instead of the default procession.

;;; - :split-data.    ;; the mix/max beat duration of bars generated; can be nil, whereupon bars
   ;; will not be split
;;; 
;;; RETURN VALUE
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defun make-rthm-chain (id num-beats 1-beat-rthms slower-rthms &key
                        (beat 4)
                        (1-beat-fibonacci nil)
                        (slow-fibonacci nil)
                        (players '(player1 player2))
                        (section-id 1)
                        (rests '(e q q. w))
                        (do-rests t)
                        (do-rests-curve nil)
                        (rest-re '((2 3) (3 2) (2 2) (5 1) (3 3) (8 1)))
                        (rest-cycle '((0 3) (1 1) (0 2) (2 1) (1 1) (3 1)))
                        (activity-curve '(0 10 100 10))
                        (sticking-curve '(0 2 100 2))
                        (harmonic-rthm-curve '(0 2 100 2))
                        (do-sticking t)
                        (do-sticking-curve nil)
                        (sticking-repeats '(3 5 3 5 8 13 21))
                        (sticking-rthms '(e e e. q e s))
                        (split-data '(2 5)))
;;; ****
  (make-instance 'rthm-chain
                 :id id :num-beats num-beats :1-beat-rthms 1-beat-rthms
                 :slower-rthms slower-rthms :beat beat :1-beat-fibonacci
                 1-beat-fibonacci :slow-fibonacci slow-fibonacci :players
                 players :section-id section-id :rests rests :do-rests do-rests
                 :do-rests-curve do-rests-curve :rest-re rest-re :rest-cycle
                 rest-cycle :activity-curve activity-curve :sticking-curve
                 sticking-curve :do-sticking-curve do-sticking-curve
                 :harmonic-rthm-curve harmonic-rthm-curve :do-sticking
                 do-sticking :do-sticking-curve do-sticking-curve
                 :sticking-repeats sticking-repeats :sticking-rthms
                 sticking-rthms :split-data split-data))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; this returns the 1-beat and the slower rhythms, both as rthm-seqs
;;; rthm is a rhythm object
;;; if prefer2 generate 2/2 meters rather than 4/4
(let ((slow-sticks '((2 ((nil t) (t nil)))
                     ;; so 2,3,4 refer to how many beats per bar, then the
                     ;; following lists indicate whether an event happens on
                     ;; that beat--these will be circularly cycled
                     (3 ((nil t t) (nil t nil) (t nil nil) (t nil t) 
                         (nil nil t)))
                     (1 ((t)))
                     (4 ((t nil nil nil) (t nil t nil) (nil t nil t)
                         (t nil nil t) (nil nil t nil) (nil t t nil)))))
      ;; this will be incremented and used to create the rthm-seq ids
      (count 0))
  (defun stick-rthms (rthm num &optional print prefer2)
    (if 
     (and (not rthm) (not num))
     (setf count 0)
     (progn
       (unless (rhythm-p rthm)
         (setf rthm (make-rhythm rthm)))
       (when (> (num-dots rthm) 1)
         (error "stick-rthms: can't handle rhythms with more than 1 dot: ~a"
                rthm))
       (when (listp slow-sticks)
         (setf slow-sticks (loop for meter in slow-sticks collect
                                (list (first meter) (make-cscl (second meter))))
               slow-sticks (make-assoc-list 'slow-sticks slow-sticks)))
       (incf count)
       (let* ((rthms-per-bar (cond ((factor num 3) 3)
                                   ((factor num 4) 4)
                                   ((> num 7) 4)
                                   (t 2)))
              (compound (not (zerop (num-dots rthm))))
              (numerator rthms-per-bar)
              (denominator (undotted-value rthm))
              (remainder-denominator denominator)
              (num-full-bars (floor num rthms-per-bar))
              (remainder (mod num rthms-per-bar))
              (remainder-numerator remainder)
              remainder-fast-bar beat-rthm slow-rthms slow-bars beats-per-bar
              fast-seq slow-seq full-fast-bars)
         (if compound
             (setf numerator (* 3 rthms-per-bar)
                   remainder-numerator (* 3 remainder)
                   denominator (* 2 denominator)
                   remainder-denominator denominator)
             ;; only if simple meters
             (when (= 1 remainder)
               (setf remainder-numerator (1+ numerator)
                     remainder remainder-numerator)
               (decf num-full-bars)))
         (setf full-fast-bars (loop repeat num-full-bars collect
                                   (loop repeat rthms-per-bar collect
                                        (clone rthm))))
         (when (and (= 4 numerator)
                    (< 4 denominator))
           (setf numerator 2
                 denominator (/ denominator 2)))
         (when (and (not compound)
                    (>= num-full-bars 2)
                    (= numerator 2)
                    (> denominator 4))
           (setf denominator (/ denominator 2)
                 numerator num-full-bars
                 num-full-bars 1))
         (when (and prefer2
                    (= 4 denominator)
                    (= 4 numerator))
           (setf denominator 2
                 numerator 2))
         (unless (zerop remainder)
           (setf remainder-fast-bar (loop repeat remainder collect 
                                         (clone rthm)))
           (push (list remainder-numerator remainder-denominator)
                 remainder-fast-bar))
         (push (list numerator denominator) (first full-fast-bars))
         (when print
           (format t "~&~a ~a: ~a bar(s) of ~a/~a plus ~a/~a" (data rthm) num
                   num-full-bars numerator denominator remainder-numerator
                   remainder-denominator)) 
         (setf fast-seq (make-instance
                         'rthm-seq 
                         :id (combine-into-symbol 'stick-rthms-auto count)
                         :data (list 
                                (if remainder-fast-bar
                                    (append full-fast-bars 
                                            (list remainder-fast-bar))
                                    full-fast-bars)))
               beats-per-bar (if compound
                                 (/ numerator 3)
                                 numerator)
               ;; we might have 3xE which would generate a 3/8 bar and is
               ;; compound but not according to our compound variable so don't
               ;; always have gen-beat-as-rhythm handle a compound ts rather do
               ;; so only if our compound var is t
               beat-rthm (get-beat-as-rhythm (first (bars fast-seq)) compound)
               slow-rthms (get-next (get-data-data beats-per-bar slow-sticks))
               slow-bars (loop repeat num-full-bars collect
                              (loop for beat in slow-rthms collect
                                   (if beat 
                                       (clone beat-rthm)
                                       (force-rest (clone beat-rthm))))))
         (push (list numerator denominator) (first slow-bars))
         (setf slow-seq (make-instance
                         'rthm-seq
                         :id (combine-into-symbol 'stick-rthms-auto-slow count)
                         :data (list slow-bars)))
         (unless (zerop remainder)
           (setf (bars slow-seq)
                 (append (bars slow-seq) 
                         ;; for now the remainder bar is a rest bar but we might
                         ;; want to add rthms here
                         (list 
                          (make-rest-bar 
                           (list remainder-numerator remainder-denominator)
                           t)))))       ; write-time-sig
         (unless (= (duration slow-seq)
                    (duration fast-seq))
           (error 
            "rthm-chain::stick-rthms: ~a ~a: slow-seq dur ~a fast-seq dur ~a"
            (data rthm) num (duration slow-seq) (duration fast-seq)))
         (values fast-seq slow-seq))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun rthm-chain-get-order (howmany items id            ; items is an int
                             &optional (use-fibonacci t) ; otherwise procession
                             wrap)      ; call wrap-list? if so, integer
  (let ((result 
         (if use-fibonacci
             (loop for el in (fibonacci-transitions howmany items)
                collect (1+ el))
             (procession howmany items))))
    (when wrap
      (setf result (wrap-list result wrap)))
    (make-cscl result :id id)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; SAR Wed May  2 18:34:04 BST 2012: Editing/adding robodoc entry

;;; MDE original comment:
;;; start with just 3 items/events and successively add new ones until a max of
;;; <items>--this can be a list or integer (must be a min of 4)

;;; ****f* rthm-chain/procession
;;; DATE
;;; 26-Jan-2010
;;; FUNCTION
;;; Generate a list of a specified length consisting of items extrapolated from
;;; a specified starting list. All elements of the resulting list will be
;;; members of the original list. 
;;;
;;; The method generates the new list by starting with the first 3 elements of
;;; the initial list and successively adding consecutive elements from the
;;; initial list until all elements have been added.
;;;
;;; ARGUMENTS
;;; - An integer that is the number of items in the list to be generated.
;;; - A list of at least 4 starting items or an integer >=4. If an integer is
;;;   given rather than a list, the method will process a list of consecutive
;;;   numbers from 1 to the specified integer.
;;; 
;;; OPTIONAL ARGUMENTS
;;; keyword arguments:

;;; - :peak. A decimal number >0.0 and <=1.0. This number indicates the target
;;;   location in the new list at which the last element is to finally occur,
;;;   whereby e.g. 0.7 = ~70% of the way through the resulting list. This is an
;;;   approximate value only. The last element may occur earlier or later
;;;   depending on the values of the other arguments. In particular, initial
;;;   lists with a low number of items are likely to result in new lists in
;;;   which the final element occurs quite early on, perhaps even nowhere near
;;;   the specified peak value. Default = 0.7.

;;; - :expt. A (decimal) number that indicates the "curve" that determines the
;;;   intervals at which each successive element of the initial list is
;;;   introduced to the new list. A higher number indicates a steeper
;;;   exponential curve. Default = 1.3.

;;; - :orders. The patterns by which the elements are added. The method
;;;   cyclically applies these orders, the numbers 1, 2, and 3 representing the
;;;   three least used elements at each pass. These orders must therefore
;;;   contain all of the numbers 1, 2, and 3, and those numbers only. 
;;;   Default = '((1 2 1 2 3) (1 2 1 1 3) (1 2 1 3)).

;;; 
;;; RETURN VALUE
;;; Returns two values, the first being the new list, with a secondary value
;;; that is a list of 2-item lists that show the distribution of each element
;;; in the new list.
;;; 
;;; EXAMPLE
#|
(procession 300 30 :peak 0.1)

=>
(1 2 1 2 3 4 5 4 4 6 7 8 7 9 10 11 10 11 12 13 14 13 13 15 16 17 16 18 19 20 19
   20 21 22 23 22 22 24 25 26 25 27 28 29 28 29 30 3 5 3 3 6 8 9 8 12 14 15 14
   15 17 18 21 18 18 23 24 26 24 27 1 2 1 2 30 5 6 5 5 7 9 10 9 11 12 16 12 16
   17 19 20 19 19 21 23 25 23 26 27 28 27 28 29 4 6 4 4 30 7 8 7 10 11 13 11 13
   14 15 17 15 15 20 21 22 21 24 25 26 25 26 29 1 2 1 1 30 3 6 3 8 9 10 9 10 12
   14 16 14 14 17 18 20 18 22 23 24 23 24 27 28 29 28 28 30 2 5 2 6 7 8 7 8 11
   12 13 12 12 16 17 19 17 20 21 22 21 22 25 26 27 26 26 29 3 4 3 30 5 6 5 6 9
   10 11 10 10 13 15 16 15 18 19 20 19 20 23 24 25 24 24 27 1 29 1 30 2 4 2 4 7
   8 9 8 8 11 13 14 13 16 17 18 17 18 21 22 23 22 22 25 27 28 27 29 3 5 3 5 30
   6 7 6 6 9 11 12 11 14 15 16 15 16 19 20 21 20 20 23 25 26 25 28 1 29 1 29 30
   2 4 2 2 7 9 10 9 12 13 14 13 14 17 18), ((2 12) (20 11) (14 11) (13 11) 
   (9 11) (6 11) (1 11) (29 10) (25 10) (22 10) (18 10) (17 10) (16 10) (15 10)
   (12 10) (11 10) (10 10) (8 10) (7 10) (5 10) (4 10) (3 10) (30 9) (28 9) 
   (27 9) (26 9) (24 9) (23 9) (21 9) (19 9))

(procession 300 30 :peak 0.9)

=>
(1 2 1 2 3 1 3 1 1 4 2 3 2 4 3 4 3 4 5 2 4 2 2 5 1 3 1 5 3 4 3 4 5 1 5 1 1 6 2
   5 2 6 4 5 4 5 6 3 6 3 3 7 5 6 5 7 2 6 2 6 7 6 7 6 6 8 4 7 4 8 7 8 7 8 9 7 8
   7 7 9 8 9 8 10 8 9 8 9 10 8 9 8 8 10 9 10 9 11 9 10 9 10 11 10 11 10 10 12
   10 11 10 12 11 12 11 12 13 11 12 11 11 13 12 13 12 14 12 13 12 13 14 13 14
   13 13 15 13 14 13 15 11 14 11 14 15 14 15 14 14 16 15 16 15 17 15 16 15 16
   17 16 17 16 16 18 16 17 16 18 17 18 17 18 19 17 18 17 17 19 18 19 18 20 18
   19 18 19 20 19 20 19 19 21 15 20 15 21 20 21 20 21 22 20 21 20 20 22 21 22
   21 23 21 22 21 22 23 22 23 22 22 24 23 24 23 25 23 24 23 24 25 24 25 24 24
   26 23 25 23 26 25 26 25 26 27 26 27 26 26 28 25 27 25 28 27 28 27 28 29 27
   28 27 27 29 28 29 28 30 24 29 24 29 30 26 29 26 26 30 28 29 28 30 19 29 19
   29 30 22 25 22 22 30 12 27 12 30 14 16 14 16 30 17), ((8 12) (22 11)
   (16 11) (14 11) (12 11) (11 11) (10 11) (4 11) (3 11) (2 11) (26 10) 
   (19 10) (17 10) (15 10) (13 10) (9 10) (7 10) (6 10) (5 10) (1 10)
   (29 9) (28 9) (27 9) (25 9) (24 9) (23 9) (21 9) (20 9) (18 9) (30 8))

|#
;;; SYNOPSIS
(defun procession (num-results items 
                   &key 
                   ;; what proportion of the way through should we aim to reach
                   ;; the max number of items?  NB This is approximate only:
                   ;; you may find the first occurrence of the highest element
                   ;; earlier or later depending on the values of the other
                   ;; arguments.  In particular, with a low number of items the
                   ;; highest element will be hit very early on, perhaps
                   ;; nowhere near the peak argument.
                   (peak 0.7)
                   ;; for an exponential curve going from 3 to num <items>
                   (expt 1.3)
                   ;; these are the orders we'll use at the beginning
                   ;; (cyclically). They will then be used when we've gone
                   ;; beyond 3 items by always using the 3 least used items.
                   ;; NB This must contain the numbers 1, 2, and 3 only but
                   ;; there can be 1 or any number of sublists. 
                   (orders '((1 2 1 2 3) (1 2 1 1 3) (1 2 1 3))))
;;; ****
  (let ((num-items 
         (typecase items
           (list (length items))
           (integer items)
           (t (error "procession: items must be a list or integer")))))
    (when (< num-items 4)
      (error "~a~%procession: <num-items> must be >= 4" items))
    (let* ((orders-cscl (make-cscl orders))
           ;; make sure we've got access to all items for the last 30% or so
           (num-at-full (round (* num-results peak)))
           ;; we use this curve to proceed from just 3 items at the beginning
           ;; to the full number of items by the end (or rather 70% from the
           ;; end by default).
           (max-curve (list 0 3 num-at-full num-items (1- num-results)
                            num-items))
           ;; we're going to use a hash table to keep track of how often each
           ;; item is used so we can always select the 3 least used
           (hash (make-hash-table))
           (count 0)
           (ignore '())
           (3least '())
           (spread '())
           (result '()))
      ;; init the hash table to 0 for each item
      (loop for i below num-items do
           (setf (gethash i hash) 0))
      (loop 
         while (< count num-results)
         ;; find the maximum item number at this point
         for max = (round (interpolate count max-curve :exp expt :warn nil))
         ;; cyclically get the next order from our user-given or default data
         for order = (get-next orders-cscl)
         do
         ;; once we've got the first least-used item we need to avoid getting
         ;; it again next time so keep track of this in <ignore>
           (setf ignore '()
                 ;; now get the three least used items
                 3least
                 ;; as we'll be using each item more than once (see <orders>)
                 ;; don't auto-inc, rather inc each time we use it (below).
                 (loop for least = (hash-least-used hash :end max :ignore ignore
                                                    :auto-inc nil)
                    repeat 3
                    collect least
                    do
                    ;; don't use again
                      (push least ignore))
                 ;; we have to sort from highest to lowest so that the use of
                 ;; <orders> makes sense even when we've gone beyond the first 3
                 3least (sort 3least #'<))
         ;; now map the 3 least used items onto our current <order>
           (loop for i in order 
              for itemi = (nth (1- i) 3least)
              ;; 20/4/10: have to do this test here too
              while (< count num-results)
              do
              ;; store our current item, then increment its usage as well as
              ;; count
                (push itemi result)
                (incf (gethash itemi hash))
                (incf count)))
      ;; we want to return a 1-based list (not 0) if <items> was simply a number
      (unless (listp items)
        (setf items (loop for i from 1 to num-items collect i)))
      ;; just for statistics: get the usasge data out of the hash
      (maphash #'(lambda (key val) 
                   (let ((skey (nth key items)))
                     (push (list skey val) spread)))
               hash)
      (setf result (nreverse result)
            spread (sort spread #'(lambda (x y)
                                    (> (second x) (second y)))))
      (values
       ;; from the list of items, substitute the indices in our result list
       (loop for i in result collect (nth i items))
       ;; statistics as a 2nd value (for info only)
       spread))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; return the least used key in a hashtable.
;;; <hash> must be a lisp hash-table object whose keys are all integers and
;;; values are numbers (in our usual case a count of how many times the keys
;;; have been used somewhere e.g. as indices). 
;;; <ignore> is a list of keys to ignore when processing.
;;; if <auto-inc> we will automatically increment the count of the returned
;;; key.
;;; <start> and <end> are inclusive.

;;; ****f* rthm-chain/hash-least-used
;;; FUNCTION
;;; 
;;; 
;;; ARGUMENTS
;;; 
;;; 
;;; OPTIONAL ARGUMENTS
;;; 
;;; 
;;; RETURN VALUE
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defun hash-least-used (hash &key (start 0) end ignore (auto-inc t))
;;; ****
  (unless end
    (setf end (hash-table-count hash)))
  (let ((count most-positive-fixnum)
        result)
    ;; don't forget that the keys could be in any order i.e. unsorted
    (maphash #'(lambda (key val)
                 (when (and (>= key start)
                            (<= key end)
                            (not (member key ignore))
                            ;; MDE Mon Dec 19 19:36:15 2011 -- in order to get
                            ;; the same result across different lisps, and
                            ;; bearing in mind that the keys are in any old
                            ;; order, we choose the key with the lowest value
                            ;; should several have the same value.
                            (or 
                             (and (= val count)
                                  (< key result))
                             (< val count)))
                   (setf count val
                         result key)))
             hash)
    (when auto-inc
      (incf (gethash result hash)))
    result))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; we'll need this at the split stage, hence it's not in flet/labels
(defun rthm-chain-seq-name (player rs-count)
  (read-from-string
   (format nil "~a-~d" player rs-count)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun rthm-chain-p (thing)
  (typep thing 'rthm-chain))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EOF rthm-chain.lsp
