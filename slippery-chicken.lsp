;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****c* sc/slippery-chicken
;;; NAME 
;;; slippery-chicken
;;; 
;;; File:             slippery-chicken.lsp
;;;
;;; Class Hierarchy:  named-object -> slippery-chicken
;;;
;;; Version:          0.9.0
;;;
;;; Project:          slippery chicken (algorithmic composition)
;;;
;;; Purpose:          Implementation of the slippery-chicken class.
;;;
;;; Author:           Michael Edwards: m@michael-edwards.org
;;;
;;; Creation date:    March 19th 2001
;;;
;;; $$ Last modified: 12:20:31 Wed Apr 25 2012 BST
;;;
;;; SVN ID: $Id$ 
;;;
;;; ****
;;; Licence:          Copyright (c) 2010 Michael Edwards
;;;
;;;                   This file is part of slippery-chicken
;;;
;;;                   slippery-chicken is free software; you can redistribute
;;;                   it and/or modify it under the terms of the GNU General
;;;                   Public License as published by the Free Software
;;;                   Foundation; either version 2 of the License, or (at your
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

;;; (eval-when (compile)
;;;    (declaim (optimize (speed 3) (safety 3) (space 0) (debug 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :slippery-chicken)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass slippery-chicken (named-object)
  ((rthm-seq-palette :accessor rthm-seq-palette :initarg :rthm-seq-palette
                     :initform nil)
   (rthm-seq-map :accessor rthm-seq-map :initarg :rthm-seq-map :initform nil)
   ;; 24.3.11: method shorten-large-fast-leaps uses a max duration for a fast
   ;; note in seconds as a key arg, but it's hard to access as a user, so
   ;; specify it as part of the sc class.
   (fast-leap-threshold :accessor fast-leap-threshold 
                        :initarg :fast-leap-threshold :initform 0.125)
   ;;****S* slippery-chicken/rthm-seq-map-replacements 
   ;; NAME
   ;; rthm-seq-map-replacements 
   ;; These are replacements for the map (which may be generated
   ;; algorithmically); they take the form (section-reference
   ;; sequence-number (1-based) replacement) e.g.
   ;;  '(((1 1 vla) 2 20a) ((1 1 vla) 3 1a) ((1 1 vla) 4 9a) ((1 1 vla) ...
   ;; ****
   (rthm-seq-map-replacements :accessor rthm-seq-map-replacements 
                              :initarg :rthm-seq-map-replacements
                              :initform nil)
   (pitch-seq-map :accessor pitch-seq-map :initform nil)
   (set-palette :accessor set-palette :initarg :set-palette :initform nil)
   (set-map :accessor set-map :initarg :set-map :initform nil)
   (set-map-replacements :accessor set-map-replacements 
                         :initarg :set-map-replacements :initform nil)
   (hint-pitches :accessor hint-pitches :initarg :hint-pitches :initform nil)
   (ensemble :accessor ensemble :initarg :ensemble :initform nil)
   ;; when players play more than one instrument this is the change-map where
   ;; the changes of instrument are given (using sequence not bar numbers).
   ;; N.B. instruments cannot be changed mid-sequence, only between
   ;; sequences!!!  When a player plays more than one instrument, then the
   ;; instrument for bar one must be given.
   (instrument-change-map :accessor instrument-change-map :initarg
                          :instrument-change-map :initform nil)
   ;; this can contain bar references or bar numbers and looks something like
   ;; '((1 (q 160)) ((2 2 2) 96)) (200 (q 120 "meno mosso")))
   ;; where 1 is the bar, q is the beat and 160 is the bpm.  The (2 2 2) is a
   ;; reference to a bar of the form (section-number sequence-number
   ;; bar-number).  References are converted to bar numbers before being stored
   ;; in the map.
   (tempo-map :accessor tempo-map :initarg :tempo-map :initform nil)
   ;; 24.1.11 we can also specify a tempo curve and this will generate the
   ;; tempo-map for us.  The x scale will be fitted to the number of bars and a
   ;; new tempo will be written every X bars, as indicated in the first
   ;; argument in the list (10 in the following example); the second element is
   ;; the beat rhythm e.g.  '(10 q (0 60 100 120)) NB the curve should start at
   ;; 0 but the map will start at 1
   (tempo-curve :accessor tempo-curve :type list :initarg :tempo-curve 
                :initform nil)
   ;; this contains the instrument definitions referenced in the ensemble.
   (instrument-palette :accessor instrument-palette
                       :initarg :instrument-palette :initform nil)
   ;; in CMN: which instruments should write bar numbers in the score?  
   ;; MDE Wed Apr 18 09:46:40 2012 -- if NIL we'll use the instruments at the
   ;; top of each group 
   (instruments-write-bar-nums :accessor instruments-write-bar-nums
                               :type list :initarg :instruments-write-bar-nums
                               :initform nil)
   ;; when choosing notes for instruments we take into account notes that other
   ;; instruments are already playing--this limits the available notes.  So the
   ;; order in which the instruments are allocated notes is important: specify
   ;; the order you want in this slot; the default is simply the list of
   ;; players in (players (ensemble sc))
   (instruments-hierarchy :accessor instruments-hierarchy :type list
                          :initarg :instruments-hierarchy :initform nil)
   ;; in the case of the sndfile-palette, we put the palette first in a list,
   ;; the paths second and the extensions third
   (snd-output-dir :accessor snd-output-dir
                   :initarg :snd-output-dir :initform "/tmp/")
   ;; see clm-play method for a description of this slot.
   (sndfile-palette :accessor sndfile-palette :initarg :sndfile-palette
                    :initform nil)
   (bars-per-system-map :accessor bars-per-system-map 
                        :initarg :bars-per-system-map :initform nil)
   ;; where the braces and bar lines should be drawn, starting from the top of
   ;; the score.  i.e. (3 2 7) means the first three instruments are grouped,
   ;; then the next 2, then the next 7.  This is checked at initialization to
   ;; add up to the number of players in the ensemble.
   ;; *** N.B. This overides the bar-line-writers slot of the ensemble!
   (staff-groupings :accessor staff-groupings :type list 
                    :initarg :staff-groupings :initform nil)
   (piece :accessor piece :initform nil)
   ;; ties to beginnings of rthm-seqs are generally not allowed so
   ;; warnings are issued when they're detected; however in some cases
   ;; they're desirable so turn warnings on or off.
   ;; 15/7/05 now obsolete but leave it for backwards compatibility
   (warn-ties :accessor warn-ties :type boolean :initarg :warn-ties
              :initform t)
   ;; the following two slots allow for defining ranges for players across
   ;; the whole piece.  E.g. :set-limits-high '((vibes (0 g4 100 f6))) will
   ;; limit the notes selected from the sets to those below g4 at the beginning
   ;; but up to f6 by the end.  Inbetween there is interpolation.  The x-axis
   ;; can be any arbitrary range.  Y values can be note names or midi note
   ;; numbers.  These always refer to sounding pitches.
   ;; NB if a curve is given with the id 'all', then this will act as a global
   ;; curve and be applied to all instruments, overriding their individual
   ;; curves. Also, though the X axes of these curves can have arbitrary
   ;; ranges, they will be scaled to conform to the number of sequences in the
   ;; piee and interpolated once per sequence; so if you need precision it's
   ;; actually better to use sequence numbers as X values, not bars.
   (set-limits-high :accessor set-limits-high :initarg :set-limits-high 
                    :initform nil)  
   (set-limits-low :accessor set-limits-low :initarg :set-limits-low 
                   :initform nil)  
   ;; 31.1.11: this title will be used in lilypond file names so it's perhaps
   ;; best to avoid spaces etc.
   (title :accessor title :initarg :title :initform "slippery-chicken-piece")
   ;; MDE Fri Dec  9 19:43:58 2011 -- for lilypond
   (composer :accessor composer :initarg :composer :initform nil)
   ;; 10/3/07: simply a list of bar numbers where a rehearsal letter should be
   ;; written (automatically)
   (rehearsal-letters :accessor rehearsal-letters :type list 
                      :initarg :rehearsal-letters :initform nil)
   ;; 1/4/06: this is the number of sections __and__ subsections
   (num-sequences :accessor num-sequences :type integer :initform -1)
   ;; MDE Tue Apr 10 08:27:24 2012 -- the get-notes function would avoid
   ;; melodic octaves by default but make this a slot option now 
   (avoid-melodic-octaves :accessor avoid-melodic-octaves :type boolean
                          :initarg :avoid-melodic-octaves :initform t)
   ;; MDE Mon Mar 26 13:10:15 2012 -- This one defines the lowest scaler we'll
   ;; accept before adding notes from those used i.e. if our pitch-seq needs 6
   ;; notes and only 3 are available, there would be note repetition but as
   ;; this would create a scaler of 0.5, that would be acceptable
   (pitch-seq-index-scaler-min :accessor pitch-seq-index-scaler-min
                               :initarg :pitch-seq-index-scaler-min 
                               :initform 0.5)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod initialize-instance :after ((sc slippery-chicken) &rest initargs)
  (declare (ignore initargs)
           (special +slippery-chicken-standard-instrument-palette+))
  ;; MDE Sat Mar 31 09:27:31 2012 
  (unless (pitch-seq-index-scaler-min sc)
    (setf (pitch-seq-index-scaler-min sc) 0.5))
  ;; MDE Thu Jan 12 11:15:13 2012 -- in order to clone we need to be able to
  ;; init the object without slot values then setf them afterwards 
  (when (and (set-map sc) (ensemble sc) (rthm-seq-map sc) (rthm-seq-palette sc)
             (set-palette sc))
    (let ((given-tempo-map (tempo-map sc)))
      (flet ((make-name (name) (format nil "~a-~a" (id sc) name)))
        (setf (instrument-palette sc)
              (cond ((instrument-palette-p (instrument-palette sc))
                     ;; clone objects if they're already initialised outside of
                     ;; make-slippery-chicken, so that any changes we make here
                     ;; don't affect the outside objects.
                     (clone (instrument-palette sc)))
                    ((instrument-palette sc)
                     (make-instrument-palette
                      (make-name 'instrument-palette)
                      (instrument-palette sc)))
                    ;; 15.11.11 if none given, use the standard palette
                    (t +slippery-chicken-standard-instrument-palette+))
              (ensemble sc)
              (if (ensemble-p (ensemble sc))
                  (clone (ensemble sc))
                  (apply #'make-ensemble 
                         ;; got to do the apply to make sure we use the key
                         ;; arguments, if any
                         (append
                          (cons (make-name 'ensemble)
                                (ensemble sc))
                          (list :instrument-palette
                                (instrument-palette sc)))))
              (instrument-change-map sc)
              (if (instrument-change-map-p
                   (instrument-change-map sc))
                  (clone (instrument-change-map sc))
                  (make-instrument-change-map
                   (make-name 'instrument-change-map)
                   (instrument-change-map sc)))
              (set-palette sc)
              (let ((sp (set-palette sc)))
                (if (set-palette-p sp)
                    (clone sp)
                    ;; MDE Fri Apr 6 22:28:52 2012 -- a two-note set would
                    ;; result in a recursive ral being made (because
                    ;; recurse-simple-data is T by default) so we can't just
                    ;; call make-set-palette, rather, apply instead, so that
                    ;; :recurse-simple-data NIL can be part of the list that is
                    ;; applied to make-set-palette.  But this is tricky because
                    ;; if we want to pass keyword args to make-set-palette when
                    ;; creating a set-palette directly in
                    ;; make-slippery-chicken, then we need an extra level of
                    ;; list e.g.
                    ;; 
                    ;; '(((1 ((g2 d3 a3 b3)))
                    ;;    (2 ((d3 b3)))) 
                    ;;   :recurse-simple-data nil))
                    ;; 
                    ;; as opposed to what we've always done and want to
                    ;; continue doing in the vast majority of cases e.g.
                    ;; 
                    ;;'((1 ((g2 d3 a3 b3)))
                    ;;  (2 ((d3 b3))))
                    ;;
                    ;; so in order to make this backward compatible, see if the
                    ;; second element of the list is a symbol
                    ;; (i.e. keyword--and remembering of course that (symbolp
                    ;; NIL) -> T!) and if it is use apply, otherwise just call
                    ;; directly:
                    (if (and (second sp) (symbolp (second sp)))
                        (apply #'make-set-palette
                               (cons (make-name 'set-palette)
                                     sp))
                        (make-set-palette (make-name 'set-palette)
                                          sp)))))
        ;; don't just make a set-map with nil!!!!
        (when (set-map sc)
          (setf (set-map sc) 
                (clone-with-new-class ;; 11.3.10 set-map is its own class now
                 (if (sc-map-p (set-map sc))
                     (let ((clone (clone (set-map sc))))
                       (setf (replacements clone) (set-map-replacements sc))
                       clone)
                     (make-sc-map (make-name 'set-map)
                                  (set-map sc) 
                                  :replacements 
                                  (set-map-replacements sc)
                                  :recurse-simple-data nil))
                 'set-map)))
        (unless (sc-map-p (set-map sc))
          (error "~a~%slippery-chicken::initialize-instance:~%~
                    Cannot proceed: set map is either nil or not a set map!"
                 (set-map sc)))
        ;; 29/3/10: it's not ok to have nil references in the set-palette
        ;; MDE Thu Mar  1 20:24:39 2012 -- method changed name from (link)
        (bind-palette (set-map sc) (set-palette sc) nil)
        (link-named-objects (set-palette sc))
        (link-named-objects (set-map sc))
        (check-first-bar-ins-for-doubling-players (ensemble sc)
                                                  (instrument-change-map sc)
                                                  (this (get-first 
                                                         (set-map sc))))
        (setf (snd-output-dir sc) (trailing-slash (snd-output-dir sc))
              (rthm-seq-palette sc)
              (if (rsp-p (rthm-seq-palette sc))
                  (clone (rthm-seq-palette sc))
                  (make-rsp (make-name 'rthm-seq-palette)
                            (rthm-seq-palette sc)))
              (rthm-seq-map sc)
              (if (rthm-seq-map-p (rthm-seq-map sc))
                  (let ((clone (clone (rthm-seq-map sc))))
                    (setf (replacements clone) (rthm-seq-map-replacements sc))
                    clone)
                  (make-rthm-seq-map 
                   (make-name 'rthm-seq-map)
                   (rthm-seq-map sc)
                   :recurse-simple-data nil
                   :replacements 
                   (rthm-seq-map-replacements sc))))
        ;; it's ok to have nil in the rthm-seq-maps of course
        ;; MDE Thu Mar  1 20:24:39 2012 -- method changed name from (link)
        (bind-palette (rthm-seq-map sc) (rthm-seq-palette sc))
        (check-instruments sc)
        (check-maps (set-map sc)
                    (rthm-seq-map sc))
        (setf (pitch-seq-map sc)
              (if (sc-map-p (pitch-seq-map sc))
                  (clone (pitch-seq-map sc))
                  (generate-pitch-sequence-map (rthm-seq-map sc) sc))
              (hint-pitches sc)
              (if (change-map-p (hint-pitches sc))
                  (clone (hint-pitches sc))
                  (make-change-map (make-name 'hint-piches) 
                                   t
                                   (hint-pitches sc))))
        (let ((sfp (sndfile-palette sc)))
          (setf (sndfile-palette sc)
                (if (sndfile-palette-p sfp)
                    (clone sfp)
                    (make-sfp (make-name 'sound-file-palette)
                              (first sfp) 
                              :paths (second sfp)
                              :extensions (third sfp)))))
        (setf (num-sequences sc) (count-sequence-refs (set-map sc)))
        (handle-set-limits sc)
        ;; (print (set-limits-low sc))
        ;; we have a chicken before the egg situation here: we can't
        ;; create a tempo-map without a piece because we need
        ;; reference to the bar numbers, but we can't create a piece
        ;; without a tempo-map because we need the tempi to calculate
        ;; start times.  As a solution, create a piece with a
        ;; temporary tempo-map of qtr=60 then update it later.
        (setf (tempo-map sc) '((1 60))
              (piece sc) (sc-make-piece sc (warn-ties sc))
              ;; map might be nil as we have a curve instead so handle this
              (tempo-map sc) (tempo-curve-to-map given-tempo-map
                                                 (tempo-curve sc)
                                                 (num-bars sc))
              ;; this calls the setf method so it's not as useless as it
              ;; looks.  
              (bars-per-system-map sc) (bars-per-system-map sc)))
      (linked (rthm-seq-map sc))
      (link-named-objects (rthm-seq-map sc))
      (let ((sg (staff-groupings sc)))
        (if sg
            (unless 
                (and (listp sg)
                     (= (num-players (ensemble sc))
                        (loop for i in sg do 
                             (unless (integer>0 i)
                               (error 
                                "slippery-chicken::initialize-instance:~
                              staff-groupings should be a list of ~
                              integers: ~a"
                                sg))
                             sum i)))
              (error "slippery-chicken::initialize-instance: ~%~
                  staff-groupings should be a list of integers summing ~
                  to the number ~%of instruments in the ensemble:  ~a"
                     sg))
            ;; 10.11.11: if no staff-groupings given, just make the whole
            ;; ensemble one big group
            (setf (staff-groupings sc) (list (num-players (ensemble sc))))))
      ;; the order of players in the piece (from rthm-seq-map) is alphabetical,
      ;; but we want them as given in the ensemble...
      (setf (players (piece sc)) (players (ensemble sc)))
      ;; make a double bar at end of piece
      (change-bar-line-type sc (num-bars (piece sc)) 2)
      ;; have to call this again now that we've got the real tempo-map
      (update-slots sc (tempo-map sc) 0.0 0.0 1 nil nil (warn-ties sc))
      (update-instruments-total-duration sc)
      ;; (print (get-data 1 (set-palette sc)))
      ;; 25.3.11 the make-slippery-chicken function might set this to nil thus
      ;; overriding the class default 
      (unless (fast-leap-threshold sc)
        (setf (fast-leap-threshold sc) 0.125))
      (format t "~&Shortening short, fast leaps...")
      (format t "~&Shortened ~a large fast leaps"
              (shorten-large-fast-leaps sc :verbose nil))
      ;; make sure tempo changes get registered in midi output
      (update-events-tempo sc)
      ;; 28.1.11
      (check-time-sigs sc)
      ;; 5.4.11
      (cleanup-rest-bars sc)
      (set-rehearsal-letters sc (get-groups-top-ins sc)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod print-object :before ((sc slippery-chicken) stream)
  (format stream "~%SLIPPERY-CHICKEN:~
                  ~%                      title: ~a ~
                  ~%                   composer: ~a ~
                  ~%                set-palette: ~a ~
                  ~%                    set-map: ~a ~
                  ~%               hint-pitches: ~a ~
                  ~%               rthm-seq-map: ~a ~
                  ~%           rthm-seq-palette: ~a ~
                  ~%                  tempo-map: ~a ~
                  ~%                tempo-curve: ~a ~
                  ~%         instrument-palette: ~a ~
                  ~%                   ensemble: ~a ~
                  ~%      instruments-hierarchy: ~a ~
                  ~%        fast-leap-threshold: ~a ~
                  ~%      avoid-melodic-octaves: ~a ~
                  ~% pitch-seq-index-scaler-min: ~a"
          (title sc) (composer sc) (id (set-palette sc)) (id (set-map sc))
          (id (hint-pitches sc)) (id (rthm-seq-map sc))
          (id (rthm-seq-palette sc)) (id (tempo-map sc)) (tempo-curve sc)
          (id (instrument-palette sc)) (id (ensemble sc))
          (instruments-hierarchy sc) (fast-leap-threshold sc) 
          (avoid-melodic-octaves sc) (pitch-seq-index-scaler-min sc))
  (statistics sc stream))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/clone
;;; FUNCTION
;;; Copy (clone) the instance and all data associated with the slippery-chicken
;;; object.  
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object you want to copy/clone
;;; 
;;; RETURN VALUE  
;;; a slippery-chicken object
;;; 
;;; EXAMPLE
#|
(let ((min
       (make-slippery-chicken
        '+minimum+
        :instrument-palette +slippery-chicken-standard-instrument-palette+
        :ensemble '(((fl (flute :midi-channel 1))))
        :set-palette '((1 ((c4 d4 e4 f4 g4 a4 b4 c5))))
        :set-map '((1 (1)))
        :rthm-seq-palette '((1 ((((4 4) - e e e e - - e e e e -)))))
        :rthm-seq-map '((1 ((fl (1))))))))
  (clone min))
|#
;;; SYNOPSIS
(defmethod clone ((sc slippery-chicken))
;;; ****
  (clone-with-new-class sc 'slippery-chicken))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod clone-with-new-class :around ((sc slippery-chicken) new-class)
  (declare (ignore new-class))
  (let ((no (call-next-method)))
    (setf (slot-value no 'rthm-seq-palette) (clone (rthm-seq-palette sc))
          (slot-value no 'rthm-seq-map) (clone (rthm-seq-map sc))
          (slot-value no 'rthm-seq-map-replacements)
          (my-copy-list (rthm-seq-map-replacements sc))
          (slot-value no 'pitch-seq-map) (clone (pitch-seq-map sc))
          (slot-value no 'set-palette) (clone (set-palette sc))
          (slot-value no 'set-map) (clone (set-map sc))
          (slot-value no 'set-map-replacements)
          (slot-value no 'fast-leap-threshold) (fast-leap-threshold sc)
          (my-copy-list (set-map-replacements sc))
          (slot-value no 'hint-pitches) (clone (hint-pitches sc))
          (slot-value no 'instrument-palette) (clone (instrument-palette sc))
          (slot-value no 'ensemble) (clone (ensemble sc))
          (slot-value no 'instrument-change-map) 
          (clone (instrument-change-map sc))
          (slot-value no 'tempo-map) (clone (tempo-map sc))
          (slot-value no 'tempo-curve) (my-copy-list (tempo-curve sc))
          (slot-value no 'instruments-write-bar-nums) 
          (copy-list (instruments-write-bar-nums sc))
          (slot-value no 'snd-output-dir) (snd-output-dir sc)
          (slot-value no 'sndfile-palette) (clone (sndfile-palette sc))
          (slot-value no 'bars-per-system-map) (clone (bars-per-system-map sc))
          (slot-value no 'staff-groupings) (copy-list (staff-groupings sc))
          (slot-value no 'piece) (clone (piece sc))
          (slot-value no 'title) (title sc)
          (slot-value no 'composer) (composer sc)
          (slot-value no 'warn-ties) (warn-ties sc)
          (slot-value no 'set-limits-high) (my-copy-list (set-limits-high sc))
          (slot-value no 'set-limits-low) (my-copy-list (set-limits-low sc))
          (slot-value no 'rehearsal-letters) 
          (my-copy-list (rehearsal-letters sc))
          (slot-value no 'avoid-melodic-octaves) (avoid-melodic-octaves sc) 
          (slot-value no 'pitch-seq-index-scaler-min)
          (pitch-seq-index-scaler-min sc)
          (slot-value no 'num-sequences) (num-sequences sc))
    no))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/num-notes
;;; FUNCTION
;;; Returns the number of attacked notes i.e. not including ties or rests.
;;; 
;;; ARGUMENTS
;;; - a slippery-chicken object 
;;; 
;;; RETURN VALUE
;;; An integer
;;; 
;;; EXAMPLE
#|
(let ((min
       (make-slippery-chicken
        '+minimum+
        :instrument-palette +slippery-chicken-standard-instrument-palette+
        :ensemble '(((fl (flute :midi-channel 1))))
        :set-palette '((1 ((c4 d4 e4 f4 g4 a4 b4 c5))))
        :set-map '((1 (1)))
        :rthm-seq-palette '((1 ((((4 4) - e e e e - - e e e e -)))))
        :rthm-seq-map '((1 ((fl (1))))))))
  (num-notes min))
=> 8
|#
;;; SYNOPSIS
(defmethod num-notes ((sc slippery-chicken))
;;; ****
  (num-notes (piece sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/cmn-display
;;; FUNCTION
;;; cmn-display:
;;; Write the score as an EPS (Encapsulated Postscript) file using CMN. Caveat:
;;; this might fail if you generated Lilypond files first; if so, regenerate
;;; your slippery-chicken object and re-call cmn-display.  Several of the key
;;; arguments are passed directly to CMN and so are named accordingly.
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object
;;; - &key arguments:
;;; - :respell default T. T means respell according to slippery chicken's
;;;    algorithm only.  A list of notes which should be changed to their
;;;    enharmonics once respelling has been done can also be passed e.g. '((vln
;;;    (13 2) (14 3)) ...  (cl (14 3 t) ... )).  This refers to the player then
;;;    as many note references for that player as needed e.g. (13 2) = bar 13
;;;    note 2 (1-based and counting tied notes but not rests).  The t in the cl
;;;    refers to changing the written note as the default is to change the
;;;    sounding note spelling only.  Chords are not respelled by the default
;;;    algorithm so if these need to be respelled do so in the list e.g. (vln
;;;    (13 (2 1)))
;;; - :start-bar default NIL.  What bar to start the score at (default NIL = at
;;;    the first bar). 
;;; - :start-bar-numbering default NIL.  The bars will be numbered every
;;;    five bars starting from this number (or 1 if NIL).
;;; - :auto-bar-nums default NIL. This is separate from and in addition to the
;;;    bar-number written in every part every 5 bars so use with caution.  It
;;;    corresponds to CMN's automatic-measure-numbers.  If set to e.g. 1 it
;;;    will print every bar number at the top of each system, or if :by-line, at
;;;    the start of each line.
;;; - :end-bar default NIL.  What bar to end the score at (default NIL = at the
;;;    last bar).
;;; - :title default T. Write the title to the EPS file?  If T, use the title
;;;    slot of the slippery-chicken object, if a string, use that, otherwise, no
;;;    title. 
;;; - :file default "/tmp/cmn.eps".  Which EPS file to write.
;;; - :all-output-in-one-file default t.  Write separate pages (NIL) or all
;;;    pages to one file (T).
;;; - :one-line-per-page default NIL.  Write just one line (system) on each
;;;    page? 
;;; - :staff-separation default 3. The separation between lines within a group,
;;;    in CMN's units.
;;; - :line-separation default 5.  The separation between systems (i.e. not
;;;    groups, but a line of music for the whole ensemble).
;;; - :empty-staves default NIL. Whether an empty stave should be displayed
;;;    under each instrument for e.g. manually editing with pencil
;;; - :write-section-info default NIL. Write the section number/refs into the
;;;    score?  NB This might not work before regenerating the slippery-chicken
;;;    object from scratch.
;;; - :group-separation default 2. Separation of groups in a system, in CMN's
;;;    units.  
;;; - :system-separation default cmn::line-mark.  The gap between systems.  If
;;;    cmn::page-mark only one system will be written per page.
;;; - :process-event-fun default NIL. A user-defined function that takes one
;;;    argument, an event object.  The function will be called for each event
;;;    in the piece. Could be used e.g. to algorithmically add accents,
;;;    dynamics, or change the colour of notes, etc.
;;; - :display-sets default NIL.  Display on a separate treble-bass system the
;;;    set used for each rthm-seq.
;;; - :rehearsal-letters-all-players default NIL. By default, rehearsal letters
;;;    are put over the bar lines of those instruments at the top of each
;;;    group.  If T, the letters will be put over all instruments (useful when
;;;    writing parts).
;;; - :display-marks-in-part default NIL.  The marks-in-part slot of the rhythm
;;;    class (e.g. text) are added to parts only, i.e. they're not in the main
;;;    score.  If T, write these to the score also.
;;; - :tempi-all-players default NIL.  Similar to rehearsal-letters-all-players.
;;; - :players default NIL.  If NIL, write all players to the score.  If a list
;;;    of valid players, write only those.
;;; - :page-height default 29.7.  The page height in centimeters.
;;; - :page-width default 21.0.   The page width in centimeters.
;;; - :size default 15.  CMN's overall size scaler.
;;; - :page-nums default T.  Write the page numbers?
;;; - :in-c default T.  Display the score in C or if NIL, at written pitch.
;;;    N.B. Piccolo/double bass keep the usual octave transpositions.
;;; - :auto-clefs default T.  Automatically insert clefs into those instruments
;;;    that use more than one clef?
;;; - :multi-bar-rests NIL.  When writing parts, use multiple bar rests (T) or
;;;    write each bar with a separate rest (NIL)?
;;; - :automatic-octave-signs default NIL.  Insert octave signs automatically
;;;    when notes would otherwise need too many ledger lines?
;;; - :display-time default NIL.  Write time (mins:secs) on the first event
;;;    of each bar?
;;; - :add-postscript default NIL.  Postscript code to be added to the EPS file
;;;    after it has been written.  See the add-ps-to-file function afor
;;;    details.
;;;
;;; RETURN VALUE  
;;; always T
;;; 
;;; SYNOPSIS
#+cmn
(defmethod cmn-display ((sc slippery-chicken) 
                       &key
                        (respell-notes t)
                        (start-bar nil)
                        (start-bar-numbering nil)
                        (end-bar nil)
                        ;; MDE Fri Apr  6 13:27:08 2012 
                        (title t)
                        (file "/tmp/cmn.eps")
                        (all-output-in-one-file t)
                        (one-line-per-page nil)
                        (staff-separation 3)
                        (line-separation 5)
                        (empty-staves nil)
                        (write-section-info nil)
                        (group-separation 2)
                        (system-separation cmn::line-mark)
                        (process-event-fun nil)
                        (display-sets nil)
                        (rehearsal-letters-all-players nil)
                        (display-marks-in-part nil)
                        (tempi-all-players nil)
                        (players nil)
                        (page-height 29.7)
                        (page-width 21.0)
                        (size 15)
                        (auto-bar-nums nil)
                        (page-nums t)
                        (in-c t)
                        (auto-clefs t)
                        (multi-bar-rests nil)
                        (automatic-octave-signs nil)
                        (display-time nil)
                        (add-postscript nil))
;;; ****
  ;; MDE Wed Apr 18 10:57:41 2012 -- 
  (set-write-bar-num sc)
  (when respell-notes
    (respell-notes sc respell-notes))
  ;; MDE Wed Apr 11 12:09:13 2012
  (setf players
        (cond ((listp players) players)
              ((and players (symbolp players)) (list players))
              (t (players (ensemble sc)))))
  (when rehearsal-letters-all-players 
    (set-rehearsal-letters sc players))
  (when tempi-all-players 
    (update-events-tempo sc players))
  (when multi-bar-rests
    (multi-bar-rests sc players)
    (when (or start-bar end-bar)
      (warn "slippery-chicken:: cmn-display: when using multi-bar-rests the ~
             whole piece will be generated: ignoring start/end-bar!")))
  (when auto-clefs
    (format t "~&Inserting automatic clefs....")
    (auto-clefs sc :players players :verbose nil :in-c in-c
                :delete-marks-before nil))
  ;; 26/4/10: some processes turn notes into rests so turn bars of rests only
  ;; into rest-bars proper 
  (cleanup-rest-bars sc)
  (cmn-display (piece sc)
               :auto-bar-nums auto-bar-nums
               :start-bar start-bar
               :display-marks-in-part display-marks-in-part
               :start-bar-numbering start-bar-numbering
               :page-nums page-nums
               :group-separation group-separation
               :end-bar end-bar
               :multi-bar-rests multi-bar-rests
               :bars-per-system-map (bars-per-system-map sc)
               :ensemble (ensemble sc)
               :all-output-in-one-file all-output-in-one-file
               :one-line-per-page one-line-per-page
               :instrument-change-map (instrument-change-map sc)
               :system-separation system-separation
               :file file
               :title (cond ((stringp title) title)
                            ((eq title T) (title sc)))
               :process-event-fun process-event-fun 
               :set-map (when display-sets (set-map sc))
               :empty-staves empty-staves
               :staff-groupings (staff-groupings sc)
               :write-section-info write-section-info
               :staff-separation staff-separation
               :line-separation line-separation
               :players players
               :in-c in-c
               :page-height page-height
               :page-width page-width
               :automatic-octave-signs automatic-octave-signs
               :display-time display-time
               :size size)
  (when add-postscript
    (add-ps-to-file file add-postscript))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod convert-bar-refs-to-numbers ((sc slippery-chicken) map)
  ;; replace any bar references with the true bar numbers
  (loop 
     with bnum
      for pair in map
      for bar = (first pair)
      for i from 0 do
        ;; when the bar number is a reference (of the form (section
        ;; sequenz-num bar-num)), then get the bar number of that
        ;; reference and replace it before making the
        ;; simple-change-map 
        (when (listp bar)
          ;; MDE Thu Feb 23 10:37:54 2012 -- make sure the ref is legal
          (setf bnum (get-bar-num-from-ref
                      sc (first bar) (second bar) (third bar)))
          (if bnum
              (setf (first (nth i map)) bnum)
              (error "slippery-chicken::convert-bar-refs-to-numbers:: 
                      can't get bar number for reference ~a" bar))))
  map)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod (setf bars-per-system-map) (bpsm (sc slippery-chicken))
  (unless (simple-change-map-p bpsm)
    (setf bpsm (make-simple-change-map (format nil "~a-~a" (id sc) 
                                               'bars-per-system-map)
                                       (convert-bar-refs-to-numbers sc bpsm))))
  (setf (slot-value sc 'bars-per-system-map) bpsm)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod (setf tempo-map) (tm (sc slippery-chicken))
  (setf tm (convert-bar-refs-to-numbers sc tm)
        (slot-value sc 'tempo-map)
        (make-tempo-map (format nil "~a-~a" (id sc) 'tempo-map)
                        tm)))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod (setf set-map-replacements) :after (smr (sc slippery-chicken))
  (setf (replacements (set-map sc)) smr))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod (setf rthm-seq-map-replacements) :after (rsmr (sc slippery-chicken))
  (setf (replacements (rthm-seq-map sc)) rsmr))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Called by initialize-instance

(defmethod check-instruments ((sc slippery-chicken))
  (let* ((rsm-players (players (rthm-seq-map sc)))
         (ensemble-players (players (ensemble sc)))
         (ensemble-players-len (length ensemble-players))
         (hierarchy (instruments-hierarchy sc)))
    (if hierarchy
        (progn
          (unless (= (length hierarchy) (length (remove-duplicates hierarchy)))
            (error "slippery-chicken::check-instruments: instrument-hierarchy ~
                    contains duplicates!: ~a" hierarchy))
          (unless (= (length hierarchy) ensemble-players-len)
            (error "slippery-chicken::check-instruments: instrument-hierarchy ~
                    ~a must contain all the players of the ensemble ~a."
                   hierarchy ensemble-players))
          (loop for ins in hierarchy do
               (unless (member ins ensemble-players)
                 (error "slippery-chicken::check-instruments: ~
                          instrument-hierarchy ~a must contain all the ~
                          players of the ensemble ~a. You gave ~a"
                        hierarchy ensemble-players ins))))
        (setf (instruments-hierarchy sc) (copy-list ensemble-players)))
    (unless (= (length rsm-players) ensemble-players-len)
      (warn "slippery-chicken::check-instruments: ~%Number of instruments ~
             in the rthm-seq-map is not the same ~%as that in the ensemble!"))
    (if (instruments-write-bar-nums sc)
        (loop for bw in (instruments-write-bar-nums sc)
           unless (member bw ensemble-players) do
             (error "slippery-chicken::check-instruments:  ~
                     instruments-write-bar-nums contains reference to ~
                     instrument not in ensemble: ~a ~a" bw ensemble-players))
        ;; MDE Wed Apr 18 09:49:30 2012 -- 
        (when (staff-groupings sc)
          (setf (instruments-write-bar-nums sc)
                (get-groups-top-ins sc))))
    (loop for rsmp in rsm-players 
       unless (member rsmp ensemble-players) do
       (error "slippery-chicken::check-instruments: rthm-seq-map player ~a ~
                  not defined in ensemble" rsmp))
    t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Called by initialize-instance

;;; Clone the rthm-seq-map, loop through all the instruments in all the
;;; sections of the rsm (get-first then thereafter use the next slot).  Get the
;;; list of rthm-seq refs, pass this with the section ref and the instrument to
;;; make-section-for player.  In the rms-clone, replace the data of the current
;;; element with a section which is a list of sequenzs made by promoting the
;;; rthm-seq to a sequenz.

;;; Go through each and every bar for each instrument and update the
;;; write-time-sig slot of each rthm-seq-bar.

;;; Go through each event of each rthm-seq-bar and update compound-duration to
;;; reflect tempo.  Then call handle-first-note-ties for each rthm-seq (to
;;; update compound durations of tied first notes of a bar dependent upon tempo
;;; also--a tempo could change over a tie between bars). 

;;; Go through each event and update start-time based on compound duration
;;; (only when the event has need-new-note).

(defmethod sc-make-piece ((sc slippery-chicken) &optional (warn-ties t))
  (let* ((rsm-clone (link-named-objects (clone (rthm-seq-map sc)))))
    (setf rsm-clone (sc-change-class rsm-clone 'piece))
    (rsm-to-piece rsm-clone sc)
    (setf (id rsm-clone) (format nil "~a-piece" (id sc))
          ;; the players from the rthm-seq-map might be in a different order
          ;; from those of the ensemble so copy the latter. 
          (players rsm-clone) (players (ensemble sc)))
    (add-rest-player-sections rsm-clone)
    (add-rest-sequenzes rsm-clone)
    (update-slots rsm-clone (tempo-map sc) 0.0 0.0 1 nil nil warn-ties)
    (handle-ties rsm-clone)
    ;; well, not ideal, but we have to do this again because of the
    ;; ties.  First we need to do it to get bar numbers etc. for the
    ;; sequenzes, then we have to do it after the handle-ties to make
    ;; sure the compound-durations take tempo into consideration
    (update-slots rsm-clone (tempo-map sc) 0.0 0.0 1 nil nil warn-ties)
    (update-write-time-sig rsm-clone t)
    ;; 28.1.11 use -sig2 also to make sure each bar is really checked.
    (update-write-time-sig2 rsm-clone t)
    rsm-clone))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  ****m* slippery-chicken/update-slots
;;; FUNCTION
;;; Called by initialize-instance and others.  Updates timings of events and
;;; statistics.  Not generally called by the user but can be useful if
;;; post-generation editing has changed something fundamental to the structure.
;;; 
;;; ARGUMENTS
;;; - a slippery-chicken object
;;; 
;;; OPTIONAL ARGUMENTS
;;; - a tempo-map object (not just as a list). If not given, then the tempo-map
;;;   from the slippery-chicken object will be used (default = NIL).
;;; - the start-time of the first event, in seconds (default = 0.0).
;;; - the start-time of the first event, in 'quarters' (for MIDI timing)
;;;   (default = 0.0).
;;; - the starting bar number (default = 1)
;;; - the reference of the current section (for internal recursive use in the
;;;   bar-holder class) (default = NIL).
;;; - the nth sequence (for internal recursive use in the sequenz class)
;;;   (default = NIL)
;;; - whether to warn when ties are used to the beginning of a sequence.  This
;;;   argument is now obsolete and ignored, but remains for some backward
;;;   compatibility (default T).
;;; 
;;; RETURN VALUE
;;; The duration in seconds of the object, in this class, the whole generated
;;; piece. 
;;; 
;;; SYNOPSIS
(defmethod update-slots ((sc slippery-chicken) 
                         &optional
                         (tempo-map nil)
                         (start-time 0.0)
                         (start-time-qtrs 0.0)
                         (start-bar 1)
                         (current-section nil)
                         (nth nil)
                         (warn-ties t)
                         (update-write-bar-nums nil))
;;; ****
  (prog1
      (update-slots (piece sc) 
                    (if tempo-map tempo-map (tempo-map sc))
                    start-time start-time-qtrs start-bar current-section nth
                    warn-ties)
    (when update-write-bar-nums
      (set-write-bar-num sc))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod update-instruments-total-duration ((sc slippery-chicken))
  (loop for player in (players sc) do
       (loop for bar-num from 1 to (num-bars sc) 
          for bar = (get-bar sc bar-num player)
          for ins = (get-instrument-for-player-at-bar player bar-num sc)
          do
            (gen-stats bar)
            (incf (total-duration ins) (sounding-duration bar)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Wed Apr 18 10:10:58 2012 -- currently only works for CMN.
(defmethod set-write-bar-num ((sc slippery-chicken) &optional (every 5))
  ;; (print 'write-bar-num)
  (loop for player in (players sc) do
       (loop for bar-num from 1 to (num-bars sc) do
            (setf (write-bar-num (get-bar sc bar-num player)) nil)))
  (loop for player in (instruments-write-bar-nums sc) do
       (loop for i from (1- every) to (1- (num-bars sc)) by every do
          (setf (write-bar-num (get-bar sc i player)) t)))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Called by rsm-to-piece (function)

;;; Loop through each rthm-seq reference, get the rthm-seq, pull out the
;;; associated pitch-seq from the pitch-seq-map (using the 'this' ref of the
;;; instrument as lookup into the psm).  Get the harmony for this seq, the
;;; hint-pitch, and for each rthm-seq call sc-make-sequenz

;;; In order to be able to limit sets, we have to keep count of the number of
;;; sequences as we proces them.  This has to be done on an instrument by
;;; instrument basis however, as the piece is not generated seq by seq (all
;;; instruments in one go).  So seq-count becomes an assoc-list with each
;;; player as keys and the data being the count of sequences.

(let ((seq-count nil))
  (defmethod make-section-for-player (lno (sc slippery-chicken) 
                                      &optional
                                      ;; this is the last event of the previous
                                      ;; section (which could be nil)
                                      last-event
                                      ;; this is the last pitch we saw (could
                                      ;; be in a previous section)
                                      last-pitch-seen)
    (flet ((inc-seq-count (player-ref)
             (let ((p (get-data player-ref seq-count nil)))
               (if p
                   (incf (data p)) ;; seq-count 1-based
                 (add (list player-ref 1) seq-count)))))
      (if (not (or lno last-event))
          (setf seq-count (make-assoc-list nil nil))
        (let* ((rthm-seq-refs (data lno))
               (player-section-ref (this lno))
               (player-ref (first (last player-section-ref)))
               (section-ref (butlast player-section-ref))
               (last-note-previous-seq last-event)
               (last-pitch last-pitch-seen)
               (player-section (clone-with-new-class lno 'player-section)))
          (setf (data player-section)
            (loop for rsr in rthm-seq-refs and seq-num from 0 do
                  (inc-seq-count player-ref)
                collect
                  ;; collect nil when the player sits this seq out
                  (when rsr
                    (let* ((rs (get-data rsr (rthm-seq-palette sc)))
                           (pitch-seq (get-nth-from-map player-section-ref
                                                        seq-num
                                                        (pitch-seq-map sc)))
                           (set (get-nth-from-palette section-ref seq-num
                                                      (set-map sc)))
                           hint-pitch seq)
                      (multiple-value-bind
                          ;; have to get the second values result here so we
                          ;; know whether to trigger a program-change or not
                          (instrument instrument-change)
                          (get-current-instrument-for-player 
                           section-ref player-ref (1+ seq-num) sc)
                        #|
                        (when instrument-change
                          (format t "~&ins-change! seq ~a, ~a" seq-num
                          instrument))
                          |#
                        (setf hint-pitch (cm-get-data (hint-pitches sc)
                                                      player-section-ref)
                              seq
                              (sc-make-sequenz rs instrument set pitch-seq
                                               hint-pitch player-ref 
                                               player-section-ref seq-num 
                                               last-note-previous-seq
                                               sc (get-data-data player-ref
                                                                 seq-count)
                                               instrument-change last-pitch)
                              last-note-previous-seq (get-last-event seq))
                        (when (pitch-or-chord last-note-previous-seq)
                          (setf last-pitch (pitch-or-chord 
                                            last-note-previous-seq))))
                      seq))))
          player-section)))))
          
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Called by get-set-limits method
(defmethod get-set-limit-high ((sc slippery-chicken) player seq-num)
  (get-set-limit-aux (set-limits-high sc) player seq-num))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Called by get-set-limits method
(defmethod get-set-limit-low ((sc slippery-chicken) player seq-num)
  (get-set-limit-aux (set-limits-low sc) player seq-num))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-player
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
(defmethod get-player ((sc slippery-chicken) player)
;;; ****
  (get-data player (ensemble sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/num-bars
;;; FUNCTION
;;; num-bars:
;;;
;;; Return the number of bars in the piece.
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object
;;; 
;;; RETURN VALUE  
;;; The number of bars (integer).
;;; 
;;; SYNOPSIS
(defmethod num-bars ((sc slippery-chicken))
;;; ****
  (num-bars (piece sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-bar-from-ref
;;; FUNCTION
;;; get-bar-from-ref:
;;;
;;; Return a rthm-seq-bar object from the piece.  Sequenz-num and bar-num are
;;; 1-based. 
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object
;;; - the section reference/id (symbol, number, list)
;;; - the player (symbol)
;;; - the sequence number in the section (integer, counting from 1)
;;; - the bar number in the sequence (integer, counting from 1)
;;; 
;;; RETURN VALUE  
;;; the rthm-seq-bar object
;;; 
;;; SYNOPSIS
(defmethod get-bar-from-ref ((sc slippery-chicken) section player
                             sequenz-num bar-num)
;;; ****
  (get-bar-from-ref (piece sc) section player sequenz-num bar-num))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; sequenz-num and bar-num are 1-based.

;;; ****m* slippery-chicken/get-bar-num-from-ref
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
(defmethod get-bar-num-from-ref ((sc slippery-chicken) section
                                 sequenz-num bar-num)
;;; ****
   (get-bar-num-from-ref (piece sc) section sequenz-num bar-num))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; N.B. although optional, the player argument is required.  It is optional so
;;; that we can have a sequenz method with the same name which only requires
;;; the bar-num argument. 

;;; 15/3/03: change this so that if player is nil, then we get the bar for all
;;; players in the ensemble. 

;;; ****m* slippery-chicken/get-bar
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
(defmethod get-bar ((sc slippery-chicken) bar-num &optional player)
;;; ****
  ;; (unless player
  ;; (error "bar-holder::get-bar: player argument is required!"))
  (if player
      (get-bar (piece sc) bar-num player)
      (let ((players (players (ensemble sc))))
        (loop for p in players collect (get-bar (piece sc) bar-num p)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; This will only work for single notes, not chords.

(defmethod respell-notes-aux ((sc slippery-chicken) &optional corrections)
  (loop for player in (players sc) do
        ;; (print player)
        (respell-notes-for-player sc player)
        ;; we can't ignore instruments that only sound octaves +/- written note
        ;; as that would leave written and sounding notes potentially
        ;; different. 
        (when (plays-transposing-instrument (get-player sc player) nil)
          (respell-notes-for-player sc player t)))
  (respell-bars sc)
  ;; we're really doing this only for the effect of having all ties go to the
  ;; same note instead of enharmonics
  ;; (print 'check-ties)
  (check-ties sc t)
  ;; (print 'corrections)
  (when (and corrections (listp corrections))
    (enharmonic-spellings sc corrections))
  ;; have to do it here to correct some ties to notes with accidentals
  (auto-accidentals sc)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/count-notes
;;; FUNCTION
;;; count-notes:
;;;
;;; Returns the number of notes between start-bar and end-bar (both inclusive).
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object
;;; - start-bar (integer)
;;; - end-bar (integer)
;;; - (optional just-attacks default nil): whether to count just the number of
;;; notes that need new events or the number of notes in the score. NB a chord
;;; counts as one note only.
;;; - (optional players default nil): the players whose notes we want to count;
;;; can be a single symbol or a list of players; if nil all players will be
;;; counted. 
;;; 
;;; RETURN VALUE  
;;; the number of notes (integer)
;;; 
;;; EXAMPLE
;;; (count-notes +altogether+ 416 417 nil 'pno-rh) -> 10
;;; 
;;; SYNOPSIS
(defmethod count-notes ((sc slippery-chicken) start-bar end-bar 
                        &optional just-attacks players)
;;; ****
  (unless players
    (setf players (players sc)))
  (unless (listp players)
    (setf players (list players)))
  (loop 
      with count = 0
      for bnum from start-bar to end-bar do
        (loop 
            for player in players 
            for bar = (get-bar sc bnum player)
            do
              (incf count (if just-attacks 
                              (notes-needed bar)
                            (num-score-notes bar))))
      finally (return count)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 9.4.11: note can be a single pitch or a chord (list). start and end bar are
;;; inclusive.  
;;; ****m* slippery-chicken/find-note
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
(defmethod find-note ((sc slippery-chicken) player note &key (written nil)
                      start-bar end-bar)
;;; ****
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (next-event sc player nil start-bar)
  (let* ((chord? (listp note))
         (find (if chord? (make-chord note) (make-pitch note)))
         p)
    (loop for e = (next-event sc player) while e do
         (when (> (bar-num e) end-bar)
           (return))
         (setf p (if written (written-pitch-or-chord e) (pitch-or-chord e)))
         (when (and p (if chord?
                          (and (chord-p find) (chord-p p) (chord-equal find p))
                          (and (pitch-p find) (pitch-p p) (pitch= find p))))
           (format t "~&bar ~a" (bar-num e))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/players
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
(defmethod players ((sc slippery-chicken))
;;; ****
  (players (piece sc)))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let ((current-bar nil)
      (current-bar-num 1)
      (current-event-num 0))
  ;; ****m* slippery-chicken/next-event
  ;; FUNCTION
  ;; Get the events from the piece one after the other (e.g. in a loop).  This
  ;; needs to be called with a bar number the first time to reset; this will
  ;; return nil, after which calling without a bar number will return the
  ;; events. 
  ;; 
  ;; ARGUMENTS 
  ;; - the slippery-chicken object
  ;; - the player (symbol)
  ;; - (optional default nil): whether to return only notes that need attacks or
  ;; tied notes too
  ;; - (optional default nil): the bar to start at (number, see above); this
  ;; should be nil after the first call to reset; when it's nil when we
  ;; actually get events returned.
  ;; - (optional default nil): the end bar (number)
  ;; 
  ;; RETURN VALUE  
  ;; 
  ;; 
  ;; EXAMPLE
  ;; 
  ;; 
  ;; SYNOPSIS
  (defmethod next-event ((sc slippery-chicken) player 
                         &optional
                         (attacked-notes-only nil)
                         ;; could be a number too, whereupon it's the bar
                         ;; number to start at  
                         (start-over nil)
                         (end-bar nil)) ; inclusive
;;; **** 
    (cond (start-over
           (setf current-bar-num (if (integer>0 start-over)
                                     start-over
                                     1)
                 current-bar nil
                 current-event-num 0)
           nil)
          ;; another hacked trick: if attack-notes-only is a
          ;; number, inc current-even-num by that amount
          ;; this of course means attacked-notes-only no longer works so we're
          ;; just dealing with any old events...
          ((numberp attacked-notes-only)
           (unless current-bar
             (error "slippery-chicken::next-event: no current-bar!"))
           (loop 
              with direction = (if (< attacked-notes-only 0)
                                   -1
                                   1)
              repeat (abs attacked-notes-only) do
              (cond ((and (= direction -1)
                          (zerop current-event-num))
                     (decf current-bar-num)
                     (setf current-bar nil
                           current-event-num (1- (num-rhythms 
                                                  current-bar))))
                    ((and (= direction 1)
                          (= current-event-num (num-rhythms current-bar)))
                     (decf current-event-num))
                    (t (incf current-event-num direction)))))
          ;; if player is nil just return the bar num: useful for debugging.
          ((not player) current-bar-num)
          ;; the usual case:
          ((<= current-bar-num (if end-bar
                                   end-bar
                                   (num-bars (piece sc))))
           (unless current-bar
             (setf current-bar (get-bar sc current-bar-num player)
                   current-event-num 0))
           (unless current-bar
             (error "slippery-chicken::next-event: no bar number ~a!" 
                    current-bar-num))
           (if (< current-event-num (num-rhythms current-bar))
               (progn
                 (let ((result (nth current-event-num (rhythms current-bar))))
                   (incf current-event-num)
                   (if (and attacked-notes-only
                            (not (needs-new-note result)))
                       (next-event sc player attacked-notes-only nil end-bar)
                       result)))
               (progn
                 (setf current-bar nil
                       current-event-num 0)
                 (incf current-bar-num)
                 (next-event sc player attacked-notes-only nil end-bar)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-note
;;; FUNCTION
;;; Get a numbered event for a player from a bar of a slippery-chicken object. 
;;; 
;;; NB slippery-chicken doesn't have 'note' and 'rest' classes, rather both
;;; these are events.  So the nomenclature 'note' and 'rest' are used here and
;;; elsewhere merely for convenience to distinguish between sounding and
;;; non-sounding events.
;;;
;;; See also rthm-seq-bar methods for accessing notes by other means.
;;; 
;;; ARGUMENTS
;;; - the slippery-chicken object
;;; - the bar number (integer, counting from 1)
;;; - the note number, counting tied notes (integer, counting from 1).  This
;;;   can also be a list if accessing pitches in a chord (see below). 
;;; - the player (symbol)
;;; 
;;; OPTIONAL ARGUMENTS
;;; - (optional default nil) whether, when accessing a pitch in a chord,
;;;    whether to return the written or sounding pitch.  
;;; 
;;; RETURN VALUE
;;; An event object.
;;; 
;;; EXAMPLE
#|
(let ((mini
       (make-slippery-chicken
        '+mini+
        :title "mini"
        :instrument-palette +slippery-chicken-standard-instrument-palette+
        :snd-output-dir "/tmp"
        :sndfile-palette
        '(((audio-1 (phrenos-beg.wav)))
          ("/snd/"))
        :ensemble '(((vn (violin :midi-channel 1))))
        :tempo-map '((1 (q 60)))
        :set-palette '((1 ((c4 d4 e4 f4 g4 a4 b4 c5))))
        :set-map '((1 (1)))
        :rthm-seq-palette '((1 ((((2 4) (e) e+e. 32 (32)))
                                :pitch-seq-palette (((1) 2)))))
        :rthm-seq-map '((1 ((vn (1))))))))
  (print (data (get-rest mini 1 2 'vn)))
  (print (data (get-note mini 1 2 'vn)))
  (print (data (get-note mini 1 '(2 1) 'vn)))
  (print (data (get-note mini 1 '(2 2) 'vn)))
  (is-tied-from (get-note mini 1 1 'vn)))

=>
32 
"E." 
C4 
D4 
T

|#
;;; SYNOPSIS
(defmethod get-note ((sc slippery-chicken) bar-num note-num player 
                     &optional written)
;;; ****
  (get-note (piece sc) bar-num note-num player written))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-rest
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
(defmethod get-rest ((sc slippery-chicken) bar-num rest-num player)
;;; ****
  (get-rest (piece sc) bar-num rest-num player))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****m* slippery-chicken/get-event
;;; FUNCTION
;;; get-event:
;;;
;;; 
;;; 
;;; ARGUMENTS 
;;; 
;;; 
;;; RETURN VALUE  
;;; 
;;; 
;;; EXAMPLE
;;; 
;;; 
;;; DATE
;;; 
;;; 
;;; SYNOPSIS
(defmethod get-event ((sc slippery-chicken) bar-num event-num player)
;;; ****
  (get-event (piece sc) bar-num event-num player))
;;; ****

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod tie-all-last-notes-over-rests-aux ((sc slippery-chicken)
                                  start-bar end-bar player
                                  &key (to-next-attack t)
                                  (tie-next-attack nil)
                                  ;; what to tie to on end-bar only
                                  (last-rhythm nil)
                                  (auto-beam nil))
  (let* ((active-bars (loop
                         for bnum from start-bar to (1- end-bar)
                         for bar = (get-bar (piece sc) bnum player)
                         unless (is-rest-bar bar)
                         collect bnum))
         (last (first (last active-bars))))
    ;; (print active-bars)
    (loop for bnum in active-bars do
         (tie-over-rest-bars-aux sc bnum player 
                                 :end-bar end-bar
                                 :tie-next-attack tie-next-attack
                                 :to-next-attack to-next-attack
                                 :auto-beam auto-beam
                                 :last-rhythm (when (= bnum last)
                                                last-rhythm)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; bar-num is the bar that we start the ties from the last note, not the first
;; rest bar.  
(defmethod tie-over-rest-bars-aux ((sc slippery-chicken) bar-num player
                                   &key (end-bar 99999) 
                                        (to-next-attack t)
                                        (tie-next-attack nil)
                                        (last-rhythm nil)
                                        (auto-beam nil))
  (let* ((bar (get-bar (piece sc) bar-num player))
         (start-event-pos nil)
         (start-event (when bar 
                        (multiple-value-bind
                            (start-event pos)
                            (get-last-attack bar nil)
                          (setf start-event-pos pos)
                          start-event)))
         (porc (when (and start-event
                          (not (is-rest start-event)))
                 (clone (pitch-or-chord start-event))))
         (wporc (when (and start-event
                           (written-pitch-or-chord start-event))
                  (clone (written-pitch-or-chord start-event))))
         (last-event start-event)
         last-bar)
    ;; (print porc)
    (unless (zerop (notes-needed bar))
      (unless porc
        (error "slippery-chicken::tie-over-rest-bars-aux: can't tie from last ~
              event of bar ~a" bar-num))
      ;; remove any staccato or tenuto marks from this event
      (rm-marks start-event '(s t as) nil)
      (when porc
        (delete-marks porc))
      (when wporc
        (delete-marks wporc))
      ;; replace accent-staccato with just accent
      (replace-mark start-event 'as 'a)
      ;; our last event may have been tied to following events...
      (loop 
          for i from start-event-pos
          while (is-tied-from start-event)
          do
            (setf start-event (get-nth-event (1+ i) bar)))
      (setf (is-tied-from start-event) t)
      (no-accidental porc)
      (when wporc
        (no-accidental wporc))
      ;; (format t "~&acc: ~a" (show-accidental porc)) ;;(first (data porc))))
      (flet ((do-it (e)
               (setf (pitch-or-chord e) (clone porc)
                     (written-pitch-or-chord e) (when wporc 
                                                  (clone wporc))
                     (is-rest e) nil
                     (needs-new-note e) nil
                     (is-tied-to e) t
                     (is-tied-from e) t
                     last-event e)))
        ;; first the events in the current bar
        (loop 
            for i downfrom (1- (num-rhythms bar)) to 0
            for e = (nth i (rhythms bar))
            while (is-rest e)
            do
              (do-it e))
        ;; now the events in the next bars
        (loop 
            for bnum from (1+ bar-num) 
            for bar = (get-bar (piece sc) bnum player)
            while (<= (bar-num bar) end-bar)
            do
              (setf last-bar bar)
              (if (is-rest-bar bar)
                  (let ((events (events-for-full-bar (get-time-sig bar) 
                                                     porc wporc)))
                    (setf last-event (first (last events))
                          (rhythms bar) events)
                    (gen-stats bar))
                (progn
                  (when to-next-attack
                    ;; (loop for e in (rhythms bar) while (is-rest e) do
                    (loop for e in (rhythms bar) do
                          (if (is-rest e) 
                              (do-it e)
                            (progn
                              (when (and tie-next-attack
                                         (porc-equal e last-event))
                                ;; we've hit the next attack after the ties
                                ;; we created but if it's the same
                                ;; pitch/chord, tie to this too
                                (setf last-event nil
                                      ;; so we don't kill the tie
                                      (is-tied-to e) t)
                                (decf (notes-needed bar)))
                              (return)))))
                  (return))))
        (when last-event
          (setf (is-tied-from last-event) nil))
        (when last-rhythm
          (unless last-bar
            (setf last-bar (get-bar (piece sc) end-bar player)))
          (replace-first-event last-bar 
                               (change-rhythm
                                (clone (first (rhythms last-bar)))
                                last-rhythm))
          ;; we might have tied over several notes to the next attack so now
          ;; we've got to make them rests
          (loop 
              for e in (rest (rhythms last-bar)) 
              while (is-tied-to e)
              do
                (force-rest e)))
        (loop 
            for bnum from bar-num
            for bar = (get-bar (piece sc) bnum player)
            while (<= (bar-num bar) end-bar)
            do
              (consolidate-notes bar nil auto-beam)
              (auto-beam bar auto-beam nil))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Section is the current section reference e.g. '(2 1), player the current
;;; player e.g. 'vln.  For this section/sequence get the instrument the
;;; player is currently playing as defined in the instrument-change-map
;;; change-map.  N.B. Instruments cannot be changed mid-sequence and sequence
;;; is 1-based so we have to 1+ elsewhere if necessary

;;; ****m* slippery-chicken/get-current-instrument-for-player
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
(defmethod get-current-instrument-for-player (section player sequence
                                              (sc slippery-chicken))
;;; ****
  (unless (listp section)
    (setf section (list section)))
  (let* ((player-obj (get-data player (ensemble sc)))
         ins-obj)
    (if (doubles player-obj)
        (multiple-value-bind
              (current-ins changes-here)
            (cm-get-data (instrument-change-map sc)
                         (econs section player)
                         sequence)
          (setf ins-obj (player-get-instrument player-obj current-ins nil))
          (unless ins-obj
            (error "slippery-chicken::get-current-instrument-for-player: ~
                    Couldn't get instrument at section~a, sequence ~a, for ~a"
                   section sequence player))
          (values ins-obj changes-here))
        ;; doesn't double
        (values (get-starting-ins sc player) nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 9.2.11 do the above but for a bar number instead
;;; ****m* slippery-chicken/get-instrument-for-player-at-bar
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
(defmethod get-instrument-for-player-at-bar (player bar (sc slippery-chicken))
;;; ****
  (let* ((bar (if (rthm-seq-bar-p bar) bar (get-bar sc bar player)))
         (section (butlast (player-section-ref bar)))
         (seq-num (1+ (nth-seq bar))))
    (get-current-instrument-for-player section player seq-num sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 24.3.11: returns the number of semitones the note sounds away from the
;;; written pitch e.g. bass clarinet = -14
;;; ****m* slippery-chicken/get-transposition-at-bar
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
(defmethod get-transposition-at-bar (player bar (sc slippery-chicken))
;;; ****
  (transposition-semitones (get-instrument-for-player-at-bar player bar sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Find out the number of sequences in a section.

;;; ****m* slippery-chicken/num-seqs
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
(defmethod num-seqs ((sc slippery-chicken) section-ref)
;;; ****
  (sclist-length
   (get-data (econs 
              (if (listp section-ref) 
                  section-ref 
                (list section-ref)) 
              (first (players (piece sc))))
             (piece sc))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; The linking of the rthm-seq-map (and hence piece) slot only works at the
;;; instrument level so we don't get a pointer to the next section, rather,
;;; only when we ask for instrument data do we get the points.  Eg (get-data 3
;;; (piece sc)) will have previous, this, and next slots all NIL, whereas
;;; (get-data '(3 some-instrument) (piece sc)) will return a player-section
;;; where the previous, this, and next slots are good (this is all as it should
;;; be!).  In order to get the references of a number of contiguous sections
;;; then, we'll have to use instrument references.

;;; ****m* slippery-chicken/get-section-refs
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
(defmethod get-section-refs ((sc slippery-chicken) start-section num-sections)
;;; ****
  (let* ((last-player (first (last (players (ensemble sc)))))
         (section-list (if (listp start-section) 
                           start-section
                           (list start-section)))
         (ref section-list))
    (unless num-sections
      (setf num-sections (get-num-top-level-sections sc)))
    (loop with player-ref with data
       repeat num-sections
       ;; MDE Mon Apr 16 21:36:44 2012 -- do this only while we can get a ref
       ;; because if we start beyond section 1 but don't give num-sections
       ;; we'll be in trouble otherwise.
       while ref
       collect ref
       do 
       (setf player-ref (econs ref last-player)
             data (get-data player-ref (piece sc))
             ref (when data (butlast (next data)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 24/4/10 this is the number of sections at the top level only

;;; ****m* slippery-chicken/get-num-top-level-sections
;;; FUNCTION
;;; get-num-top-level-sections:
;;;
;;; Return the number of sections in the piece i.e. the top-level ones as
;;; defined e.g. in the set-map.  NB the num-sequences slot of slippery-chicken
;;; is the number of sections and sub-sections.
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object
;;; 
;;; RETURN VALUE  
;;; the number of sections (integer)
;;; 
;;; SYNOPSIS
(defmethod get-num-top-level-sections ((sc slippery-chicken))
;;; ****
  (num-data (set-map sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-all-section-refs
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
(defmethod get-all-section-refs ((sc slippery-chicken))
;;; ****
  ;; (get-all-refs (set-palette sc)))
  ;; 20/7/05 don't know why the palette was used, it's the map that's useful!
  (get-all-refs (set-map sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/statistics
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
(defmethod statistics ((sc slippery-chicken) &optional (stream t))
;;; ****
  (statistics (piece sc) stream))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod check-instrument-doublings ((sc slippery-chicken))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-tempo
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
(defmethod get-tempo ((sc slippery-chicken) bar-num)
;;; ****
  (data (scm-get-data bar-num (tempo-map sc))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; bar-num is actually required but optional because of the rthm-seq-bar
;;; method of the same name.

;;; ****m* slippery-chicken/get-time-sig
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
(defmethod get-time-sig ((sc slippery-chicken) &optional bar-num)
;;; ****
  (object-is-nil? bar-num "slippery-chicken::get-time-sig" 'bar-num)
  (get-time-sig (get-bar sc bar-num (first (players (ensemble sc))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Set tempo-change slot of the first event of the bar (but in each voice!)
;;; when a tempo change is indicated in the tempo-map

(defmethod update-events-tempo ((sc slippery-chicken) 
                                ;; this is a list of those players who should
                                ;; display tempo changes in the score
                                &optional display-players)
  (let* ((last-tempo (make-tempo -1))
         (current-tempo nil)
         (players (players sc)))
    (unless display-players
      (setf display-players (get-groups-top-ins sc)))
    ;; start tempo gets set in cm::process-voices
    (loop for bar-num from 1 to (num-bars (piece sc)) do
          (setf current-tempo (get-tempo sc bar-num))
          (unless (tempo-equal last-tempo current-tempo)
            ;; (print current-tempo)
            (loop 
                for player in players 
                for bar = (get-bar sc bar-num player)
                for first-event = (first (rhythms bar))
                do
                  (when (is-grace-note first-event)
                    (loop for e in (rhythms bar) do
                          (unless (is-grace-note e)
                            (setf first-event e)
                            (return))))
                  ;; of course this assumes you can't change tempo mid-bar
                  (setf (tempo-change first-event) current-tempo)
                  (setf (display-tempo first-event) 
                    (when (member player display-players)
                      t))
                  ;; (format t "~&tempo: ~a player: ~a" 
                  ;;     (tempo-change first-event) player)
                  )
            (setf last-tempo current-tempo)))
    t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod handle-set-limits ((sc slippery-chicken))
  (flet ((do-limits (set-limits num-sequences)
           (make-assoc-list 
            nil
            (loop for ins in set-limits collect
                  (list (first ins)
                        (doctor-set-limits-env (second ins) num-sequences))))))
    (let* ((ns (num-sequences sc))
           (high (do-limits (set-limits-high sc) ns))
           (low (do-limits (set-limits-low sc) ns)))
      (setf (set-limits-high sc) high
            (set-limits-low sc) low))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; global-seq-num 1-based.

(defmethod get-set-limits ((sc slippery-chicken) player global-seq-num)
  (let* ((limit-ins-high
          (get-set-limit-high sc player global-seq-num))
         (limit-ins-low 
          (get-set-limit-low sc player global-seq-num))
         ;; 10/3/07: got to take the global limits into account if an entry for
         ;; 'all was made
         (global-limit-high
          (get-set-limit-high sc 'all global-seq-num))
         (global-limit-low
          (get-set-limit-low sc 'all global-seq-num))
         (limit-high (cond ((and global-limit-high limit-ins-high)
                            (pitch-min global-limit-high limit-ins-high))
                           (global-limit-high global-limit-high)
                           ;; this could still return nil but that's handled
                           ;; elsewhere  
                           (t limit-ins-high)))
         (limit-low (cond ((and global-limit-low limit-ins-low)
                           (pitch-max global-limit-low limit-ins-low))
                          (global-limit-low global-limit-low)
                          ;; ditto
                          (t limit-ins-low))))
    ;; (format t "~&hi ~a low ~a ins-hi ~a ins-low ~a"
       ;;      (id global-limit-high) (id global-limit-low) 
          ;;  (id limit-ins-high) (id limit-ins-low))
    (list limit-low limit-high)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/shorten-large-fast-leaps
;;; FUNCTION
;;; shorten-large-fast-leaps:
;;;
;;; Attempt to tame those melodic leaps that are very fast and larger than the
;;; limit defined in the instrument class.  Called automatically at init.
;;; 
;;; ARGUMENTS 
;;; - the slippery-chicken object
;;; - threshold: the max duration of a fast note, in seconds.
;;; - whether to print what we're going (t or nil)
;;; 
;;; RETURN VALUE  
;;; always t
;;; 
;;; SYNOPSIS
(defmethod shorten-large-fast-leaps ((sc slippery-chicken) 
                                     &key threshold (verbose t))
;;; ****
  ;; 24.3.11 get threshold from class if not given
  (unless threshold
    (setf threshold (fast-leap-threshold sc)))
  (loop 
     for player in (get-players (ensemble sc))
     with global-seq-num 
     with count = 0
     do
     (setf global-seq-num 1)
     (loop for section in (get-all-section-refs sc) do
          (loop 
             for seq-num from 0
               ;; MDE Wed Feb  1 14:04:45 2012 -- don't create-rest-seq
             for seq = (get-nth-sequenz (piece sc) section player seq-num nil)
             for set = (get-nth-from-palette section seq-num (set-map sc))
             for first-bar-num = (when seq
                                   (bar-num (first (bars seq))))
             for ins = (get-current-instrument-for-player
                        section player (1+ seq-num) sc)
             for transp = (- (transposition-semitones ins))
             for lfl = (largest-fast-leap ins)
             with qnis with last-seq
             while seq do
             (unless set
               (error "slippery-chicken::shorten-large-fast-leaps: no set!~
                       ~%section = ~a seq-num = ~a" section seq-num))
             (setf qnis (get-quick-notes-indices seq last-seq 
                                                 threshold))
             (when (zerop transp)
               (setf transp nil))
             (when (and qnis lfl)
               (loop 
                  with limits = (get-set-limits sc player 
                                                global-seq-num)
                  with pitches = (limit-for-instrument 
                                  (clone set) ins
                                  :upper (second limits)
                                  :lower (first limits))
                  for qni in qnis
                  ;; a zero means we got a fast note from
                  ;; the last note last seq to the first
                  ;; note this seq
                  for e1 = (if (zerop qni)
                               (get-last-attack last-seq)
                               (get-nth-attack (1- qni) seq))
                  for e2 = (get-nth-attack qni seq)
                  for distance = (event-distance e1 e2)
                  with new-pitch with pos with compare
                  do
                  (when (> (abs distance) lfl)
                    (if (> distance 0) ;; leap up
                        (progn
                          (setf compare (lowest e1)
                                pos (position (highest e2) 
                                              pitches
                                              :test #'pitch=))
                          (unless pos
                            (error "slippery-chicken::~
                                              shorten-large-fast-leaps: ~
                                              ~a not in set!!!:~a~%pitches:~a" 
                                   (data (highest e2)) (data set)
                                   (pitch-list-to-symbols pitches)))
                          (setf new-pitch
                                (loop 
                                   for i downfrom pos to 0 
                                   for p = (nth i pitches)
                                   do
                                   (when (<= (pitch- p compare)
                                             lfl)
                                     ;; a side-effect here is that
                                     ;; quick leaps to chords are
                                     ;; replaced with single pitches 
                                     (return p)))))
                        (progn ;; leap down
                          (setf compare (highest e1)
                                pos (position (lowest e2) pitches
                                              :test #'pitch=))
                          (unless pos
                            (error "slippery-chicken::~
                                            shorten-large-fast-leaps: ~
                                            ~a not in set!!!" (highest e2)))
                          (setf new-pitch
                                (loop 
                                   for i from pos to (1- (length pitches))
                                   for p = (nth i pitches)
                                   do
                                   (when (<= (pitch- compare p)
                                             lfl)
                                     ;; a side-effect here is that
                                     ;; quick leaps to chords are
                                     ;; replaced with single pitches 
                                     (return p))))))
                    (if new-pitch
                        (flet ((doit (event)
                                 (when verbose
                                   (format t "~&seq-num ~a, ~a, ~
                                                        replacing ~a with ~a"
                                           seq-num player
                                           (id new-pitch)
                                           (id (pitch-or-chord e2))))
                                 (setf (midi-channel new-pitch)
                                       (midi-channel 
                                        (if (is-chord event)
                                            (first 
                                             (data 
                                              (pitch-or-chord event)))
                                            (pitch-or-chord event)))
                                       (marks new-pitch)
                                       (marks (pitch-or-chord event))
                                       (pitch-or-chord event)
                                       new-pitch
                                       (written-pitch-or-chord event)
                                       (when transp
                                         (set-written event transp)))))
                          (incf count)
                          (doit e2)
                          (when (is-tied-from e2)
                            ;; get the attack again but this time the
                            ;; bar and event indices of where it is 
                            (multiple-value-bind
                                  (e nth-bar nth-event)
                                (get-nth-attack qni seq)
                              (unless (and e nth-bar nth-event)
                                (error "~a~&slippery-chicken::shorten-large-~
                                        fast-leaps: couldn't get-nth-attack"
                                       seq))
                              (unless first-bar-num
                                (error "slippery-chicken::shorten-large-fast-~
                                        leaps: first-bar-num is NIL!"))
                              (loop 
                                 with bar-num = (+ nth-bar 
                                                   first-bar-num)
                                 with bar = 
                                 (get-bar sc bar-num player)
                                 with happy = t 
                                 while happy do
                                 (if bar
                                     (progn
                                       (incf nth-event)
                                       (when (>= nth-event 
                                                 (num-rhythms bar))
                                         (incf bar-num)
                                         (setf nth-event 0
                                               bar (get-bar 
                                                    sc bar-num player)))
                                       (setf e (get-nth-event
                                                nth-event bar))
                                       (when (is-tied-to e)
                                         (doit e))
                                       (unless (is-tied-from e)
                                         (setf happy nil)))
                                     (setf happy nil))))))
                        (warn "~&slippery-chicken::~
                                       shorten-large-fast-leaps: ~
                                       Couldn't get new pitch for ~a, section ~
                                       ~a, seq-num ~a, e1 ~a, e2 ~a! ~
                                       ~%pitches: ~a" 
                              player section (1+ seq-num)
                              (id (pitch-or-chord e1))
                              (id (pitch-or-chord e2))
                              (pitch-list-to-symbols pitches))))))
             (setf last-seq seq)
             (incf global-seq-num)))
     finally (return count)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 11.4.11: event-num is 1-based.  optional args actually required
;;; ****m* slippery-chicken/get-clef
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
(defmethod get-clef ((sc slippery-chicken) &optional bar-num event-num player)
;;; ****
  (let* ((bar (get-bar sc bar-num player))
         (e (when bar (get-nth-event (1- event-num) bar))))
    (when e 
      (get-clef e))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;  13.4.11: start and end bar are inclusive.
;;; at the moment, we use bass/treble clefs with 8ve signs on to indicate pitch
;;; extremes (assuming an instrument has these clefs), but these can be
;;; converted to octave brackets here.  NB no 15ma/mb handled here.
(defmethod octave-clefs-to-brackets ((sc slippery-chicken)
                                     &key players start-bar end-bar)
  (unless (listp players)
    (setf players (list players)))
  (unless players
    (setf players (players sc)))
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (loop for player in players do
       (next-event sc player nil start-bar)
       (loop with clef
          with current-clef
          with new-clef
          with octave-clef
          with last-note
          with dt
          with db
          for e = (next-event sc player) while e do
          (when (> (bar-num e) end-bar)
            (when octave-clef
              (error "slippery-chicken::octave-clefs-to-brackets (~a): got to ~
                      bar ~a but octave-clef is still ~a"
                     player (bar-num e) octave-clef))
            (return))
          (setf clef (get-clef e)
                new-clef clef
                dt (eq clef 'double-treble)
                db (eq clef 'double-bass))
          (when clef
            (if (or dt db)
                (progn
                  (setf octave-clef clef
                        new-clef (if dt 'treble 'bass))
                  (delete-clefs e)
                  (unless (eq new-clef current-clef)
                    (add-clef e new-clef))
                  (add-mark e (if dt 'beg-8va 'beg-8vb)))
                ;; if we see any other clef at all we can assume the octave
                ;; +/- is at and end, but only delete the clef if we've gone
                ;; double-x to x
                (when octave-clef
                  (setf dt (eq octave-clef 'double-treble)
                        db (eq octave-clef 'double-bass))
                  (add-mark last-note (if dt 'end-8va 'end-8vb))
                  (when (or (and dt (eq clef 'treble))
                            (and db (eq clef 'bass)))
                    (delete-clefs e))
                  (setf octave-clef nil))))
          (when octave-clef
            (setf (8va e) (if (eq octave-clef 'double-treble) 1 -1)))
         ;; (print (8va e))
          (when new-clef
            (setf current-clef new-clef))
          (unless (is-rest e)
            (setf last-note e))))
  ;; (split-octave-brackets sc :players players :start-bar start-bar
     ;;                    :end-bar end-bar)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 26.7.11 (Pula): don't allow an octave sign to extend over too many
;;; rests, rather end it and restart it.

(defmethod split-octave-brackets ((sc slippery-chicken)
                                  &key players start-bar end-bar
                                  (max-rests 4))
  (unless (listp players)
    (setf players (list players)))
  (unless players
    (setf players (players sc)))
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (let (under8v rests last-note rest-count)
    (flet ((reset ()
             (setf rests '()
                   rest-count 0
                   last-note nil)))
      (loop for player in players do
           (next-event sc player nil start-bar)
           (loop for e = (next-event sc player)
              while (and e (<= (bar-num e) end-bar)) do
              (when (and under8v (not (zerop under8v))
                         (or (has-mark e 'beg-8va)
                             (has-mark e 'beg-8vb)))
                (warn "slippery-chicken::split-octave-brackets: ~
                        ~a, bar ~a: new octavation starting when already in one"
                       player (bar-num e)))
              (setf under8v (8va e))
              ;; (print (bar-num e))
              (cond ((zerop under8v) (reset))
                    ((is-rest e)        ; under an 8ve
                     (incf rest-count)
                     (push e rests))
                    ((> rest-count max-rests) ; it's a note
                     (print (is-rest last-note))
                     (print (is-rest e))
                     (when last-note
                       (add-mark-once last-note
                                          (if (= 1 under8v) 'end-8va 'end-8vb)))
                     (add-mark-once e (if (= 1 under8v) 'beg-8va 'beg-8vb))
                     (loop for r in rests do
                          (rm-marks r '(beg-8va beg-8vb) nil)
                          (setf (8va r) 0))
                     (reset)
                     (setf last-note e))
                    (t (reset) ; a note but not too many rests
                       (setf last-note e))))))) 
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod start-octave-brackets-notes-only ((sc slippery-chicken)
                                             &key players start-bar end-bar)
  (unless (listp players)
    (setf players (list players)))
  (unless players
    (setf players (players sc)))
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (loop for player in players do
       (next-event sc player nil start-bar)
       (loop with bracket with carry with rests
          for e = (next-event sc player)
          while (and e (<= (bar-num e) end-bar)) do
          (when (zerop (8va e))
            (setf bracket nil))
          (when (and (not bracket) (not (zerop (8va e)))) ; start bracket
            (setf bracket (8va e))
            (if (is-rest e)
                (progn 
                  (setf carry bracket)
                  (push e rests))
                (setf carry nil
                      rests nil)))
          (when (and carry (not (is-rest e)))
            (print (bar-num e))
            (add-mark-once e (if (= 1 carry) 'beg-8va 'beg-8vb))
            (loop for r in rests do 
                 (rm-marks r '(beg-8va beg-8vb) nil)
                 (setf (8va r) 0))
            (setf rests nil
                  carry nil)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod end-octave-brackets-notes-only ((sc slippery-chicken)
                                           &key players start-bar end-bar)
  (unless (listp players)
    (setf players (list players)))
  (unless players
    (setf players (players sc)))
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (loop for player in players do
       (next-event sc player nil start-bar)
       (loop with bracket with rests with last-note
          for e = (next-event sc player)
          while (and e (<= (bar-num e) end-bar)) do
          (setf bracket (8va e))
          (unless (zerop bracket)
            (if (is-rest e)
                (if (or (has-mark e 'end-8va)
                        (has-mark e 'end-8vb))
                    (progn
                      (print (bar-num e))
                      (add-mark-once last-note
                                         (if (= 1 bracket) 'end-8va 'end-8vb))
                      (push e rests)
                      (loop for r in rests do 
                           (rm-marks r '(end-8va end-8vb) nil)
                           (setf (8va r) 0)))
                    ;; it's a rest without end bracket
                    (push e rests))
                ;; it's a note
                (setf last-note e))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Called automatically by cmn-display and write-lp-data-for-all

(defmethod multi-bar-rests ((sc slippery-chicken) &optional players)
  (unless (listp players)
    (setf players (list players)))
  (unless players
    (setf players (players sc)))
  (loop for player in players do
       (loop 
          with first-multi = nil
          with got-rehearsal-letter = nil
          with ins-change = nil
          with count = 0
          for bar-num from 1 to (num-bars sc)
          for bar = (get-bar sc bar-num player)
          for rest-bar = (is-rest-bar bar)
          do
          ;; is nil by default but reset here just in case we're redoing
          ;; this after editing the bars somehow.
          (setf (multi-bar-rest bar) nil
                ;; for efficiency's sake only do this if we're on a rest bar
                ins-change (when rest-bar
                             (nth-value 1 (get-current-instrument-for-player
                                           (butlast (player-section-ref bar))
                                           (first (last (player-section-ref
                                                         bar)))
                                           ;; seq is 1-based in this method call
                                           (1+ (nth-seq bar))
                                           sc))))
          (if (or (not rest-bar)
                  got-rehearsal-letter
                  (write-time-sig bar)
                  (> (bar-line-type bar) 0)
                  ;; 28.2.11 there's a pause or something on this rest...
                  (and (rhythms bar) (marks (first (rhythms bar))))
                  ;; we're in a multi-bar rest but tempo changes i.e. tempo
                  ;; change on first bar of multi is fine 
                  (and (> count 0)
                       (display-tempo (first (rhythms bar))))
                  ins-change)
              (progn
                (when (> count 1)
                  ;; we got the bar after a multi-bar rest
                  (setf (multi-bar-rest first-multi) count
                        (write-bar-num first-multi) nil))
                (setf count 0)
                (when rest-bar
                  (setf first-multi bar)
                  (incf count)))
              (progn
                (when (zerop count)
                  (setf first-multi bar))
                (incf count)
                (when (> count 1)
                  ;; this bar is part of a multi-bar rest
                  (setf (multi-bar-rest bar) t))))
          ;; remember: rehearsal letters are attached to the barline of the
          ;; __previous__ bar.... 
          (setf got-rehearsal-letter (rehearsal-letter bar)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/midi-play
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
#+cm-2
(defmethod midi-play ((sc slippery-chicken)
                      &key 
                      (start-section 1)
                      ;; these voices are used to get the actual sequence
                      ;; orders i.e. each voice will be appended to <section>
                      ;; when calling get-data.
                      ;; if nil then all voices.
                      (voices nil)
                      (midi-file "/tmp/sc.mid")
                      (time-scaler 1.0)
                      (from-sequence 1)
                      (num-sequences nil)
                      ;; if nil we'll write all the sections
                      (num-sections nil)
                      ;; if this is a 7-bit number we'll use this for all notes
                      (force-velocity nil)
                      ;; this means durations will carry over rests!
                      (ignore-rests nil))
;;; ****
  (setf voices
        (cond ((and voices (listp voices)) voices)
              ((and voices (atom voices)) (list voices))
              ((not voices) (get-players (ensemble sc)))
              (t (error "slippery-chicken::midi-play: voices = ~a!?" voices))))
  ;; (print voices)
  (let* ((voices-events (get-events-start-time-duration 
                         sc start-section voices 
                         :time-scaler time-scaler
                         :from-sequence from-sequence
                         :num-sequences num-sequences
                         :num-sections num-sections
                         :get-time-sig-changes t
                         :ignore-rests ignore-rests 
                         :include-rests t))
         ;; do all the program changes for the beginning irrespective of
         ;; whether the player changes instrument or not.  subsequent program
         ;; changes are handled in the event class.
         (midi-setup 
          (loop 
             for voice in voices
             for player = (get-player sc voice)
             for current-ins = (id (get-current-instrument-for-player
                                    start-section voice from-sequence sc))
             for ins = (get-data current-ins (instrument-palette sc))
             collect
             (list (midi-channel player) (midi-program ins))
             when (microtonal-chords-p player)
             collect
             (list (microtones-midi-channel player)
                   (midi-program ins)))))
    (cm::process-voices voices-events midi-file (get-tempo sc 1) midi-setup
                        (- (start-time-qtrs
                            (get-nth-sequenz (piece sc) start-section
                                             (first voices) 
                                             (1- from-sequence))))
                        force-velocity)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Tue Apr 17 12:16:43 2012 -- added the pitch-synchronous option.

;;; ****m* slippery-chicken/clm-play
;;; FUNCTION
;;; Using the sound files (samples) defined for the given reference in the
;;; sndfile-palette slot of slippery-chicken, write a soundfile using the pitch
;;; and timing information of the slippery-chicken score.  NB The sound file
;;; will begin with the first sounding event in the section, so if there are
;;; any leading rests, these will be skipped in the output file.
;;;
;;; By grouping sound files in the sndfile-palette slot we can generate a CLM
;;; sound file of our piece in various 'flavours': perhaps, for example, using
;;; exclusively string sounds, or percussion sounds, or a variety of sounds, as
;;; desired.  See below for an example of a sndfile-palette.
;;; 
;;; By default this method doesn't use the same events generated for the score,
;;; rather, it generates its own sequence of events and pitches.  Instead of
;;; using the pitches of the score--which might produce extreme sound file
;;; transpositions both upwards and downwards--it accesses each note of the set
;;; (assigned by the set-map to each rthm-seq) from the bottom up, one voice
;;; after another.  If do-src is T, transposition will then be calculated so
;;; that the frequency of the sound file, if given, will be shifted to the
;;; pitch of the set note.  This transposition process itself might still yield
;;; extreme transpositions, hence the note-number keyword can be changed to
;;; specify an index into the set notes for the lowest voice--though if the
;;; number of voices plus this index would then exceed the number of notes in
;;; the set, then we would wrap around to the lowest note of the set.
;;;
;;; If instead of the above method the sound files should be transposed to the
;;; pitches of the score events, set :pitch-synchronous to T and leave do-src T
;;; also.  This will work with chords too.
;;;
;;; See also sndfile-palette.lsp's make-sfp-from-wavelab-marker-file for a way
;;; of automatically creating a sndfile-palette from markers in a Steinberg
;;; Wavelab file.
;;;
;;; N.B. clm's nrev instrument will have to be loaded before calling this
;;; method.  Event amplitudes are as yet unused here.
;;; 
;;; ARGUMENTS
;;; - The slippery chicken object
;;; - The ID of the starting section
;;; - Which player(s) to write.  Can be a symbol for a single player, a list of
;;;   players, or if NIL, all players will be written.
;;; - The ID of the soundfile group from the sndfile-palette slot of the
;;;   slippery-chicken object.
;;; 
;;; OPTIONAL ARGUMENTS
;;; See below for a description of the keyword arguments:
;;; 
;;; - sound-file-palette-ref2 default NIL: if this reference is given, then we
;;;   invoke fibonacci-transitions to move from one group of sound files to
;;;   another. 
;;; - play-chance-env default '(0 100 100 100): this determines the chance that
;;;   a note will be played or not; it is a random selection but uses a fixed
;;;   seed that is re-initialized each time clm-play is called.  the following
;;;   default ensures every note will play.
;;; - play-chance-env-exp default 0.5: the exponent the above envelope's Y
;;;   values are raised to.
;;; - max-start-time default 99999999: usually we stop when we've got to the
;;;   end of the piece/section but if we specify a maximum start time here (in
;;;   seconds) events after this will be skipped.
;;; - time-scaler default 1.0: this scales duration and start-time of events
;;;   (in effect a tempo scaler)--not to be confused with duration-scaler.
;;; - normalise default .99: the maximum amplitude in the output file i.e. what
;;;   the samples should be scaled (normalised) to.
;;; - simulate default nil: if t, then clm won't be called, rather only the
;;;   sound file sequencing information will be printed for testing purposes.
;;; - from-sequence default 1: the starting sequence number.
;;; - num-sequences default nil: how many sequences to play; specifying nil
;;;   will simply play them all. 
;;; - num-sections default 1: how many sections to play. If nil, play them all.
;;; - ignore-rests default t: in contrast to other methods, rests are ignored
;;;   per default i.e. the sound files will play over the duration of rests
;;;   unless this is set to nil.  However, this is only true on a bar-by-bar
;;;   basis i.e. notes at the end of one bar will not be continued over into a
;;;   rest in the next bar.  This implies that rests at the start of a bar will
;;;   not be turned into sounding notes.
;;; - time-offset default 0.0: what time in seconds to start writing the events
;;;   into the output file.
;;; - pitch-synchronous default nil: if T, transpose the sound files (using
;;;   their frequency slot) to the pitches of the score events.  See above
;;;   description for the default behaviour.
;;; - chords default nil: usually we'll use pitches from the set-map but we
;;;   could pass a list of other sets here if preferred.
;;; - chord-accessor default nil: sometimes the chord stored in the palette is
;;;   not a simple list of data so we need to access the nth of the chord list.
;;; - note-number default 0: the nth note of the chord (from bottom) for the
;;;   lowest player.
;;; - play default nil: whether clm should play the output file or not when the
;;;   sound file is written.
;;; - amp-env default '(0 0 5 1 60 1 100 0): the amplitude envelope placed over
;;;   each segment of sound ('note').  NB If we want the original attack of the
;;;   input sound file set this to '(0 1 ....) but note that if :inc-start (see
;;;   below) is T this will probably result in clicks in the output file.
;;; - inc-start default nil: it's not always desirable to start some longer
;;;   sounds each time at the beginning, because of the repetition thus created
;;;   and the fact that we never get to other interesting parts of the sound
;;;   file .  Set this to t for start-time incrementing.  The algorithm will
;;;   increment the start time so that we reach the end of the sound file the
;;;   last time it is 'played'.
;;; - src-width default 20: the accuracy of the sample-rate conversion. This
;;;   should be an integer. The higher the value, the more accurate the
;;;   transposition, but the slower the processing.  Values of 100 might be
;;;   useful for very low transpositions.
;;; - src-scaler default 1.0: how much to scale the src values by (to increase
;;;   or decrease transposition)
;;; - do-src default T: when T, the transposition will be calculated so that
;;;   the given perceived frequency of the sound file is shifted to the pitch
;;;   of the event. But if do-src is a number or pitch symbol, then that
;;;   frequency will be matched instead.  When converted to a sample rate
;;;   conversion factor, this is multiplied by the src-scaler.
;;; - rev-amt default 0.0: the reverberation amount for nrev. NB 0.1 is a lot.
;;; - duration-scaler default 1.0: this scales the duration of events (creates
;;;   overlaps).  Not to be confused with :time-scaler.
;;; - short-file-names default nil: output file names are automatically
;;;   created.  They're usually quite long but will be shorter if this is T.
;;; - check-overwrite default t: whether to query the user before overwriting
;;;   existing sound files.
;;; - reset-snds-each-rs default t: when T, then we start over at the beginning
;;;   of the sound file group at the beginning of each rthm-seq.
;;; - reset-snds-each-player default t: when T, then we start over at the
;;;   beginning of the sound file group at the beginning of each player's part.
;;; - duration-run-over default nil: when we use a shorter segment of a sound
;;;   file as a sndfile instance, do we allow an event to go beyond the given
;;;   end point?
;;; - channels default 2: the number of sound output channels (limited only by
;;;   the sound file format).  Note that both stereo and mono sounds from the
;;;   palette will be randomly panned between any two adjacent channels.
;;; - srate default clm::*clm-srate*: the sampling rate of the output file
;;;   (independently of the input file).  This and the following two arguments
;;;   default to clm package globals. See clm.html for more options.
;;; - header-type default clm::*clm-header-type*: output sound file format.
;;;   E.g. clm::mus-riff is wave, clm::mus-aiff is aiff.
;;; - data-format default clm::*clm-data-format*: the output sound file sample
;;;   data format.  E.g. clm::mus-lfloat is 32-bit little-endian (e.g. Intel)
;;;   floating point. clm::mus-l24int is little-endian 24-bit integer.
;;; - print-secs default nil: whether clm should print the seconds computed as
;;;   it works.
;;; - output-name-uniquifier default "": give a short string here and it will
;;;   be built into the output file name (either at the end of the beginning
;;;   depending on whether short-file-names is T or NIL).
;;; - sndfile-extension default NIL: The output sound file extension
;;;   (e.g. ".wav", ".aif").  If NIL we'll try and figure out the best
;;;   extension based on the header-type.  NB the extension does not determine
;;;   the output sound file format, rather, :header-type does that.
;;; - sndfile-palette default nil: just in case we want to use an external
;;;   palette instead of the one in the slippery chicken object.
;;; 
;;; RETURN VALUE
;;; T
;;; 
;;; EXAMPLE
#|
 :sndfile-palette
 '(((raw (neumann_09.wav  neumann_24.wav 
                          neumann_10.wav  neumann_25.wav
                          neumann_11.wav  neumann_26.wav
                          neumann_01.wav  neumann_16.wav
                          neumann_28.wav  
                          neumann_02.wav  neumann_17.wav
                          neumann_30.wav 
                          neumann_03.wav  neumann_19.wav
                          neumann_33.wav 
                          neumann_06.wav  neumann_21.wav
                          neumann_08.wav  neumann_22.wav))
     ;; the above uses complete individual sound files whereas below we use the
     ;; same file many times but using different start and end points. A
     ;; 3-element list as a start or end value indicates (minutes seconds
     ;; milliseconds)   
    (p-long-continuous1
     ( ;; bowed bridge
      (skin-processed-24-48-mono.wav :start 0.341 :end 16.373)
      ;; spe
      (skin-processed-24-48-mono.wav :start (2 1 749) :end (2 10 389))
      ;; click start then bowed bridge
      (skin-processed-24-48-mono.wav :start (1 20 848) :end (1 37 152))
      ;; clb spe with battuto attack and spectral development
  ...))))

  (clm-play mini 1 nil 'p-long-continuous :num-sections 3 :play nil
            :check-overwrite nil))
|#
;;; SYNOPSIS
#+clm
(defmethod clm-play ((sc slippery-chicken) section players 
                     sound-file-palette-ref 
                     &key 
                     sound-file-palette-ref2
                     (play-chance-env '(0 100 100 100))
                     (max-start-time 99999999)
                     (play-chance-env-exp 0.5)
                     (time-scaler 1.0)
                     (normalise .99)
                     (simulate nil)
                     (from-sequence 1)
                     (num-sequences nil)
                     (num-sections 1)
                     (ignore-rests t)
                     (time-offset 0.0)
                     (chords nil)
                     (chord-accessor nil)
                     (note-number 0)
                     (play nil)
                     (amp-env '(0 0 5 1 60 1 100 0))
                     (inc-start nil)
                     (src-width 20)
                     (src-scaler 1.0)
                     (do-src t)
                     (pitch-synchronous nil)
                     (rev-amt 0.0)
                     (duration-scaler 1.0)
                     (short-file-names nil)
                     (check-overwrite t)
                     (reset-snds-each-rs t)
                     (reset-snds-each-player t)
                     (duration-run-over nil)
                     (channels 2)
                     (srate clm::*clm-srate*)
                     (header-type clm::*clm-header-type*)
                     (data-format clm::*clm-data-format*)
                     (print-secs nil)
                     (output-name-uniquifier "")
                     (sndfile-extension nil)
                     (sndfile-palette nil))
;;; ****
  ;; MDE Tue Apr 17 13:28:16 2012 -- guess the extension if none given
  (unless sndfile-extension
    (setf sndfile-extension
          (cond                         ; can't use case with clm globals
            ((or (= header-type clm::mus-aiff)
                 (= header-type clm::mus-aifc))
             ".aif")
            ((= header-type clm::mus-riff) ".wav")
            ((= header-type clm::mus-next) ".snd")
            (t (error ".aif")))))
  ;; MDE Mon Apr  2 10:23:21 2012 
  (unless (fboundp 'clm::nrev)
    (error "slippery-chicken::clm-play: clm's nrev.ins needs to be ~
            compiled and loaded for this method to run."))
  (unless num-sequences
    (setf num-sequences (num-seqs sc section)))
  (unless (listp players)
    (setf players (list players)))
  ;; MDE Mon Apr  2 09:34:36 2012 
  (unless players
    (setf players (players sc)))
  ;; re-initialise our random number generator.
  (random-rep 100 t)
  ;; 10/1/07 remove the events with a start-time after max-start-time at this
  ;; stage rather than rejecting them later (otherwise play-chance-env will
  ;; range over the full event list instead of those below max-start-time)
  (let* ((events (get-events-with-src sc section players 
                                      ;; these have 0 duration so we must ignore
                                      ;; them for now 
                                      :ignore-grace-notes t
                                      :time-scaler time-scaler
                                      :from-sequence from-sequence
                                      :num-sequences num-sequences
                                      :num-sections num-sections
                                      :ignore-rests ignore-rests
                                      :chords chords
                                      :pitch-synchronous pitch-synchronous
                                      :chord-accessor chord-accessor
                                      :note-number note-number))
         (section1-num-seqs (if num-sequences
                                num-sequences
                                (num-seqs sc section)))
         (num-players (length players))
         (events-per-player (ml 0 num-players))
         ;; clisp doesn't like (loop for player in events sum (loop for rs ...
         (total-events (loop 
                          for i from 0
                          for player in events
                          for len = (loop for rs in player sum (length rs))
                          do (setf (nth i events-per-player) len)
                          sum len))
         (snds (make-cscl (get-snds sound-file-palette-ref
                                    (if sndfile-palette
                                        sndfile-palette
                                        (sndfile-palette sc)))))
         (snds2 (when sound-file-palette-ref2
                  (make-cscl 
                   (get-snds sound-file-palette-ref2 
                             (if sndfile-palette
                                 sndfile-palette
                                 (sndfile-palette sc))))))
         (snd-transitions (loop for num-events in events-per-player collect
                               (fibonacci-transition num-events)))
         (snd nil)
         (snd-group nil)
         (srts '())
         (srt-freq (cond ((numberp do-src) do-src)
                         ((and (not (eq do-src t))
                               (symbolp do-src))
                          (note-to-freq do-src))))
         (duration 0.0)
         (wanted-duration 0.0)
         (wanted-duration-string "")
         (first-event-start nil)
         (input-start 0.0)
         (latest-possible-start 0.0)
         (available-dur 0.0)
         (event-count 1)
         (event-count-player 0)
         (events-this-rs 0)
         (output-start 0.0)
         (output-ok t)
         (this-play-chance-env '())
         (skip-this-event t)
         (total-skipped 0)
         (file-name
          (string-downcase        
           (if short-file-names
               (format nil "~{~a-~}~a~{~a-~}~{~a.~}~a-~a~a~a~a"
                       (if (listp sound-file-palette-ref) 
                           sound-file-palette-ref
                           (list sound-file-palette-ref))
                       (if sound-file-palette-ref2
                           "to-"
                           "")
                       (when sound-file-palette-ref2
                         (if (listp sound-file-palette-ref2) 
                             sound-file-palette-ref2
                             (list sound-file-palette-ref2)))
                       (if (listp section) 
                           section 
                           (list section))
                       from-sequence 
                       (+ -1 from-sequence section1-num-seqs)
                       output-name-uniquifier
                       (if pitch-synchronous "-psync" "")
                       sndfile-extension)
               (format nil "~a~a~{-~a~}~{-~a~}~{-~a~}~{-to-~a~}-seq~a-~a~a~a"
                       output-name-uniquifier
                       (string-trim "+" (id sc))
                       (if (listp section) section (list section))
                       players
                       (if (listp sound-file-palette-ref) 
                           sound-file-palette-ref
                           (list sound-file-palette-ref))
                       (when sound-file-palette-ref2
                         (if (listp sound-file-palette-ref2) 
                             sound-file-palette-ref2
                             (list sound-file-palette-ref2)))
                       from-sequence 
                       (+ -1 from-sequence section1-num-seqs)
                       (if pitch-synchronous "-psync" "")
                       sndfile-extension))))
         (output 
          (progn
            ;; first convert spaces to -'s in output file name
            (setf file-name (substitute #\- #\Space file-name))
            (format nil "~a~a"
                    (if (snd-output-dir sc)
                        (snd-output-dir sc)
                        "")
                    file-name)))
         ;; keep going (set to nil when max-start-time is exceeded)
         (happy t)
         (rthm-seqs nil))
    ;; (print 'here)
    (when (zerop (sclist-length snds))
      (error "slippery-chicken::clm-play: <snds>: No sounds for reference ~a"
             sound-file-palette-ref))
    (when (and sound-file-palette-ref2 (zerop (sclist-length snds2))
               (error "slippery-chicken::clm-play: <snds2>: ~
                       No sounds for reference ~a"
                      sound-file-palette-ref2)))
    (when (and check-overwrite (probe-file output))
      (setf output-ok 
            (yes-or-no-p "File exists: ~%~a  ~%Overwrite (yes or no) > " 
                         output)))
    (when output-ok
      (format t "~%Output file will be ~%\"~a\"~%~%" output)
      (when inc-start
        (loop for snd in (data snds) do (reset-usage snd))
        (when snds2
          (loop for snd in (data snds2) do (reset-usage snd)))
        (loop for player in events and snd-trans in snd-transitions do
             (setf snd-trans (copy-list snd-trans))
             (loop for rs in player do
                  (loop 
                     for evts in rs 
                     for snd = (if (and snds2 (= 1 (pop snd-trans)))
                                   (get-next snds2)
                                   (get-next snds))
                     do
                     ;; just to avoid the compiler warning...
                     (progn evts)
                     (unless snd
                       (error "slippery-chicken::clm-play: ~
                               snd is nil (whilst counting)!"))
                     (incf (will-be-used snd)))))
        ;; here we reset them before starting, this is correct!
        (reset snds)
        (when snds2
          (reset snds)))
      ;; MDE Tue Apr 17 18:53:36 2012 -- get the lowest start time of all the
      ;; players. events only includes sounding events here, not rests.
      (setf first-event-start 
            (loop
               for player in events 
               for ffv = (first (first player))
               if ffv minimize (start-time ffv)))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      (clm::with-sound (:scaled-to normalise 
                         :reverb clm::nrev
                         :decay-time 3
                         :output output
                         ;; these things should be default anyway but
                         ;; somehow they're not...
                         :srate srate
                         :data-format data-format
                         :header-type header-type
                         :play play :channels channels :statistics t)
        (loop 
           for player in events and player-name in players 
           and snd-trans in snd-transitions
           ;; and events-this-player in events-per-player
           and player-count from 1
           ;; 15/12/06 this while clause causes a player
           ;; not to process when
           ;; the previous overstepped the max-start-time
           ;; while happy
           do
           (setf snd-trans (copy-list snd-trans)
                 event-count-player 0
                 ;; 15/12/06 reset happy to the new player processes
                 happy t
                 this-play-chance-env 
                 (new-lastx play-chance-env
                            ;; 10/1/07 we want to use the whole
                            ;; play-chance-env when we use max-start-time:
                            ;; (1- events-this-player)))
                            ;; got to take time-offset and the start time of
                            ;; the first event into consideration, not just
                            ;; max-start-time...
                            (count-events-before-max-start 
                             player
                             (- (+ max-start-time first-event-start)
                                time-offset))))
           (format t "~%Processing player ~a/~a: ~a (resting players will ~
                          not be processed)~%"
                   player-count num-players (nth (1- player-count) players))
           (when (and (numberp num-sections) (= 1 num-sections))
             ;; MDE Tue Apr 3 09:54:46 2012 -- make sure we don't crash
             ;; if the requested instrument is sitting this section out
             (let ((rss (get-data-from-palette
                         (flatten (list section player-name))
                         (rthm-seq-map sc)
                         nil)))         ; no warning
               ;; this code will only work when we're processing 1 section
               (setf rthm-seqs 
                     (when rss
                       (subseq 
                        rss
                        (1- from-sequence)
                        (1- (+ from-sequence section1-num-seqs)))))))
           (when reset-snds-each-player
             (reset snds)
             (when snds2
               (reset snds2)))
           (loop for rs in player and rs-count from 0 while happy do
                (setf events-this-rs (length rs))
                (format t "~%    Processing rthm-seq ~a (~a events)~%"
                        ;; print the rthm-seq id if we're only doing one
                        ;; section otherwise the rthm-seq count
                        ;; MDE Tue Apr  3 09:54:46 2012 -- make sure we don't
                        ;; crash if the requested instrument is sitting this
                        ;; section out 
                        (if (and rthm-seqs (= 1 num-sections))
                            (id (nth rs-count rthm-seqs)) 
                            (1+ rs-count))
                        events-this-rs)
                (when reset-snds-each-rs
                  (reset snds)
                  (when snds2
                    (reset snds2)))
              ;; (print (length rs))
                (loop for event in rs and rs-event-count from 0 while happy
                   do
                   ;; (print 'here)
                   (setf snd-group (pop snd-trans)
                         snd (if (and snds2 (= 1 snd-group))
                                 (get-next snds2)
                                 (get-next snds))
                         duration (* duration-scaler
                                     (compound-duration-in-tempo event))
                         skip-this-event (> (random-rep 100.0)
                                            (interpolate 
                                             event-count-player 
                                             this-play-chance-env 
                                             :exp play-chance-env-exp))
                         ;; MDE Tue Apr 10 13:10:37 2012 -- see note to do-src
                         ;; keyword above. 
                         srts (if do-src
                                  ;; MDE Tue Apr 17 12:52:40 2012 -- update:
                                  ;; we now have the pitch-synchronous
                                  ;; option so need to handle chords so
                                  ;; we'll not call the pitch method here
                                  ;; but the event. This will return a list,
                                  ;; even for a single pitch, so we'll have
                                  ;; to loop through them.
                                  (src-for-sample-freq 
                                   (if srt-freq
                                       srt-freq
                                       (frequency snd))
                                   ;; MDE Tue Apr 17 12:54:06 2012 -- see
                                   ;; comment above. this used to be
                                   ;; (pitch-or-chord event)
                                   event)
                                  '(1.0)))
                   (loop for srt in srts do
                        (setf srt (* src-scaler srt))
                        (when (<= srt 0.0)
                          (error "slippery-chicken::clm-play: illegal sample ~
                             rate conversion: ~a" srt))
                      ;; MDE Mon Apr  9 12:31:07 2012
                        (unless (duration snd)
                          (error "~a~%slippery-chicken::clm-play: ~
                               sound duration is NIL!" snd))
                      ;; given the srt, what's the longest output dur
                      ;; this sound can make?  
                        (setf available-dur (/ (duration snd) srt)
                              wanted-duration-string ""
                              input-start (start snd))
                        (when skip-this-event
                          (incf total-skipped))
                        (unless snd
                          (error "slippery-chicken::clm-play: snd is nil!"))
                        (when inc-start
                          (setf latest-possible-start
                                (- (end snd) (* srt duration)))
                          (unless (and (< latest-possible-start (start snd))
                                       (not (zerop (will-be-used snd))))
                            (incf input-start 
                                  (* (has-been-used snd)
                                     (/ (- latest-possible-start (start snd))
                                        (will-be-used snd)))))
                          (incf (has-been-used snd)))
                        (when (> duration available-dur)
                          (setf wanted-duration duration
                                wanted-duration-string 
                                (if duration-run-over
                                    (format nil " (~,3f available but ~
                                                    duration-run-over is t)"
                                            available-dur)
                                    (format nil " (wanted ~,3f)"
                                            wanted-duration)))
                          (unless duration-run-over
                            (setf duration available-dur)))
                        (when (< duration 0)
                          (warn "slippery-chicken::clm-play: ~
                                  Duration < 0  ?????~%"))
                        (unless (start-time event)
                          (error "~a~%slippery-chicken::clm-play: ~
                                   no start time!!!" event))
                        (setf output-start (+ time-offset
                                              (- (start-time event)
                                                 first-event-start)))
                        (when (> output-start max-start-time)
                          (setf happy nil))
                        (when happy
                          (format t "        ~a/~a Events: ~a~
                                 ~%             ~a ~a~
                                 ~%             start-time ~,3f, input-start: ~
                                 ~,3f, ~
                                 ~%             duration ~,3f~a, ~
                                 ~%             amp ~,2f, srt ~,2f ~
                                 (pitch-or-chord ~,3f,sample freq ~,3f)~%"
                                  event-count total-events
                                  (if skip-this-event "Skipped" "Output")
                                  (path snd) 
                                  (if snds2
                                      (format nil "(snd-group ~a)" 
                                              (1+ snd-group))
                                      "")
                                  output-start 
                                  input-start duration wanted-duration-string
                                  (amplitude snd) srt 
                                  ;; MDE Tue Apr 17 13:14:45 2012 -- added
                                  ;; frequency method to chord so that this
                                  ;; doesn't fail
                                  (frequency (pitch-or-chord event))
                                  (frequency snd)))
                        (unless (or simulate skip-this-event (not happy)
                                    (zerop duration))
                          (clm::samp5 (path snd)
                                      output-start
                                      :duration duration
                                      :start input-start
                                      :srt srt
                                      :width src-width
                                      :amp (amplitude snd)
                                      :amp-env amp-env
                                      :degree
                                      ;; 2/8/05: place both mono and stereo
                                      ;; files in space randomly NB A sound
                                      ;; is always put between two speakers
                                      ;; but it could be two of any number;
                                      ;; see samp5.lsp for details.
                                      (nth (random 7) '(15 25 35 45 55 65 75))
                                      :rev-amt rev-amt
                                      :printing print-secs)))
                   (incf event-count-player)
                   (incf event-count))))))
    (unless (zerop total-events)
      (format t "~%~%~d/~d events skipped (~f%)"
              total-skipped total-events 
              (* 100.0 (/ total-skipped total-events)))))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Just calls the -aux method once for each section required.  See comments to
;;; that method for parameter explanation.

(defmethod get-events-start-time-duration
    ((sc slippery-chicken)
     start-section
     voices
     &key 
     (ignore-grace-notes nil)
     (time-scaler 1.0)
     (from-sequence 1)
     (num-sequences nil)
     (ignore-rests nil)
     (num-sections 1)
     (get-time-sig-changes nil)
     (include-rests nil))
  ;; MDE Sat Dec 17 10:16:25 2011 -- when running cheat-sheet.lsp I was getting
  ;; some invalid data in duration-in-tempo, compound-duration-in-tempo,
  ;; end-time slots; this fixed it
  (update-slots sc)
  (unless num-sections
    (setf num-sections (get-num-top-level-sections sc)))
  (let* ((sections (get-section-refs sc start-section num-sections))
         (all-sections
          (loop for section in sections
              collect (get-events-start-time-duration-aux
                       sc section voices 
                       :ignore-grace-notes ignore-grace-notes 
                       :time-scaler time-scaler
                       ;; of course the next two shouldn't be necessary when
                       ;; we're doing more than one section ...
                       :from-sequence from-sequence
                       :num-sequences num-sequences
                       :get-time-sig-changes get-time-sig-changes
                       :ignore-rests ignore-rests
                       :include-rests include-rests)))
         (voices (loop for i below (length voices) collect
                       (loop for j below num-sections
                          appending (nth i (nth j all-sections))))))
    (handle-grace-notes voices)
    voices))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; For one section, returns a list of lists, one for each voice,
;;; containing lists of event objects, one for each rthm-sequence.

(defmethod get-events-start-time-duration-aux
    ((sc slippery-chicken)
     ;; a list used as the ids for the call to get-data from the <sequences>.
     ;; If a single reference then it will be forced into a list.
     section
     ;; these voices are used to get the actual sequence orders i.e. each
     ;; voice will be appended to <section> when calling get-data
     voices
     &key 
     (ignore-grace-notes nil)
     (time-scaler 1.0)
     (from-sequence 1)
     (num-sequences nil)
     (ignore-rests nil)
     (get-time-sig-changes nil)
     (include-rests nil))
  (let* ((section-list (if (listp section) section (list section)))
         (seqs-all-ins (data (get-data section-list (piece sc)))))
    ;; (print num-sequences)
    (loop for voice in voices 
        for sqces = (data (get-data voice seqs-all-ins t))
                    ;; no longer call get-timings-from-rsp rather get the
                    ;; timings directly from the bars of the sequenzes, not
                    ;; using a tempo argument any more but using a time-scaler
                    ;; instead.  Now that we're using the piece to get the seqs
                    ;; from instead of the rthm-seq-map, we should have updated
                    ;; time information.  What we have to do though is scale
                    ;; the times and durations of each event and add the
                    ;; durations of rests to the previous note if ignore-rests
                    ;; is t.
        for events = 
          (loop for i from (1- from-sequence) to 
                (if num-sequences
                    (+ (1- from-sequence)
                       (1- num-sequences))
                  (1- (length sqces)))
              collect (get-timings (nth i sqces) time-scaler ignore-rests
                                   get-time-sig-changes include-rests 
                                   ignore-grace-notes))
        when (first events)
        collect events)))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; returns a list containing each voice: each voice has sublists of rthm-seqs:
;;; each rthm-seq contains the events.

(defmethod get-events-with-src
    ((sc slippery-chicken) from-section voices
     &key 
     (ignore-grace-notes nil)
     (time-scaler 1.0)
     (from-sequence 1)
     (num-sequences nil)
     (num-sections 1)
     (ignore-rests nil)
     ;; if chords is nil then we use the chords in the set-map
     (chords nil)
     ;; MDE Tue Apr 17 12:21:07 2012 -- whether to use the pitches of the score
     ;; events or the old method of player by player set pitch access
     (pitch-synchronous nil)
     ;; sometimes the chord stored in the palette is not a simple list of
     ;; data so we need to access the nth of the chord list
     (chord-accessor nil)
     ;; once we get to the chord, we have a list of notes, now we need the
     ;; reference to the specific note for the voices in this note list.
     ;; Either this should be single reference whereupon the first voice
     ;; will be this nth, the second this plus 1 etc., or this should be a
     ;; list.
     (note-number 0)) ;; 0-based!!!
  ;; MDE Mon Apr 16 21:44:19 2012
  (unless num-sections
    (setf num-sections (get-num-top-level-sections sc)))
  (let* ((sections (get-section-refs sc from-section num-sections))
         (all-sections
          (loop for section in sections
             collect (get-events-with-src-aux
                      sc section voices 
                      :ignore-grace-notes ignore-grace-notes
                      :time-scaler time-scaler
                      :pitch-synchronous pitch-synchronous
                      :from-sequence from-sequence
                      :num-sequences num-sequences
                      :ignore-rests ignore-rests
                      :chords chords
                      :chord-accessor chord-accessor
                      :note-number note-number))))
    ;; (print 'here)
    (loop for i below (length voices) collect
         (loop for j below num-sections
            for data = (nth i (nth j all-sections))
            when data
            append data))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod get-events-with-src-aux 
    ((sc slippery-chicken) section voices
     &key 
     (ignore-grace-notes nil)
     (time-scaler 1.0)
     (from-sequence 1)
     (num-sequences nil)
     (pitch-synchronous nil)
     (ignore-rests nil)
     (chords nil)
     (chord-accessor nil)
     (note-number 0)) ;; 0-based!!!
  (unless num-sequences
    (setf num-sequences (num-seqs sc section)))
  ;; MDE Tue Apr 17 12:22:55 2012 -- 
  (when (and pitch-synchronous (or chords chord-accessor))
    (error "slippery-chicken::get-events-with-src-aux: pitch-synchronous ~
            cannot be used in conjunction with chords or chord-accessor."))
  (let ((timings (get-events-start-time-duration-aux ; clones the events 
                  sc section voices 
                  :ignore-grace-notes ignore-grace-notes
                  :time-scaler time-scaler
                  :from-sequence from-sequence
                  :num-sequences num-sequences
                  :ignore-rests ignore-rests))
        (note-numbers (if (listp note-number) 
                          note-number 
                          (loop for i from 0 repeat (length voices)
                             collect (+ note-number i))))
        (chds 
         (if chords 
             chords
             (let ((chord-refs 
                    (subseq
                     (data (get-data section (set-map sc)))
                     (1- from-sequence)
                     (1- (+ from-sequence num-sequences)))))
               (loop for ref in chord-refs collect
                    (data (get-data ref (set-palette sc))))))))
    (when chord-accessor
      (setf chds (loop for i in chds collect (nth chord-accessor i))))
    (unless (= num-sequences (length chds))
      (error "slippery-chicken::get-events-with-src: ~
              There must be a chord for every sequence: ~a" 
             chds))
    (unless (= (length voices) (length note-numbers))
      (error "slippery-chicken::get-events-with-src: ~
              When :note-numbers is a list, ~
              then it must be of the same length as :voices"))
    ;; MDE Wed Apr 11 12:36:13 2012 -- so by default we create pitch data for
    ;; each voice that simply accesses the notes in the chord from the bottom
    ;; up, one voice after another.
    ;; MDE Tue Apr 17 12:24:18 2012 -- don't do this if pitch-synchronous
    (unless pitch-synchronous
      (loop for voice in timings and n in note-numbers do
           (loop for chord in chds 
              for num-notes = (length chord)
              for rs in voice 
              do
              (unless (simple-listp chord)
                (error "slippery-chicken::get-events-with-src: ~
                      Each chord must be a simple list of notes. ~
                      ~%Perhaps you forgot the set the :chord-accessor? ~
                      ~%~a" chord))
              (loop for event in rs 
                 ;; just in case there's less notes in the chord than
                 ;; there are voices... 
                 for pitch = (nth (mod n num-notes) chord)
                 do
                 ;; (print-simple event)
                 (unless pitch
                   (error "slippery-chicken::get-events-with-src: ~%~
                         Pitch is NIL!!!  Probably the reference ~
                         given in :note-number is out of ~%range for ~
                         the chosen chord.  ~%Current reference is ~
                         ~a into the chord ~a"  
                          n chord))
                 ;; MDE Mon Apr 16 22:03:55 2012 -- remember these events have
                 ;; been cloned so we won't be affecting score output by changing
                 ;; the pitch here.
                 (setf (pitch-or-chord event) (clone pitch))))))
    timings))
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Use the staff-groupings slot to get the instrument reference for each
;;; instrument that is first (top) in the group.

(defmethod get-groups-top-ins ((sc slippery-chicken))
  (loop 
      with nth = 0
      with players = (get-players (ensemble sc))
      for g in (staff-groupings sc)
      collect
        (nth nth players)
      do
        (incf nth g)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 10/3/07: the rehearsal-letters slot lists the bar numbers where cmn should
;;; automatically create letters.  Set the rehearsal-letter slot of the correct
;;; bars for the given player(s).
;;; e.g. (set-rehearsal-letters sc (get-groups-top-ins sc))))

(defmethod set-rehearsal-letters ((sc slippery-chicken) &optional players)
  (unless players
    (setf players (players sc)))
  (unless (listp players)
    (setf players (list players)))
  (loop 
      for bar-num in (rehearsal-letters sc)
                     ;; we have to set the rehearsal letter on the bar
                     ;; line of the previous bar
      for dc from 10 
      for letter = (format nil "~a" (digit-char dc 36))
      do 
        (when (> dc 35)
          (error "slippery-chicken::set-rehearsal-letters: ~
                  Can only make rehearsal letters from A-Z"))
        (loop 
            for player in players 
            for bar = (get-bar sc (1- bar-num) player)
            do
              (unless bar
                (error "slippery-chicken::set-rehearsal-letters: couldn't get ~
                        bar ~a for ~a." bar-num player))
              (setf (rehearsal-letter bar) letter)))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; update-write-time-sig only looks at the first bar of a seq so if we want to
;;; look at all bars and time write-time-sig accordingly call this method.

(defmethod set-write-time-sig ((sc slippery-chicken))
  (loop for player in (players sc) do
        (loop 
            with last-bar
            for bar-num from (start-bar (piece sc)) to (end-bar (piece sc))
            for bar = (get-bar sc bar-num player)
            do
              (setf (write-time-sig bar) (or (not last-bar)
                                             (not (eq t (time-sig-equal
                                                         bar last-bar))))
                    last-bar bar)))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/find-rehearsal-letters
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
(defmethod find-rehearsal-letters ((sc slippery-chicken))
;;; ****
  (loop 
      with player = (first (get-groups-top-ins sc))
      for bnum from 1 to (num-bars sc) 
      for bar = (get-bar sc bnum player)
      when (rehearsal-letter bar)
      collect (1+ bnum)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 9.4.11 NB won't allow notes to be under more than one slur/phrase mark
;;; ****m* slippery-chicken/check-slurs
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
(defmethod check-slurs ((sc slippery-chicken))
;;; ****
  (loop for player in (players sc) do
     ;; reset to the first event
       (next-event sc player nil t)
       (loop
          with in-slur
          for e = (next-event sc player)
          while e
          do
          (cond ((begin-slur-p e)
                 (if in-slur
                     (warn "slippery-chicken::check-slurs (~a): begin slur ~
                              at bar ~a but already began slur at bar ~a"
                           player (bar-num e) in-slur)
                     (setf in-slur (bar-num e))))
                ((end-slur-p e)
                 (if in-slur
                     (setf in-slur nil)
                     (warn "slippery-chicken::check-slurs (~a): end slur at ~
                              bar ~a but no begin slur"
                           player (bar-num e)))))
          finally
          (when in-slur
            (warn "slippery-chicken::check-slurs (~a): end slur missing at ~
                     end of piece" player)))))
           

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Just for checking really but if same-spellings all ties will be forced to
;;; the same spellings. 
;;; 
;;; cf piece::handle-ties

;;; ****m* slippery-chicken/check-ties
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
(defmethod check-ties ((sc slippery-chicken) &optional same-spellings)
;;; ****
  (loop for player in (players sc) do
     ;; reset to the first event
       (next-event sc player nil t)
       (loop
          with last = (next-event sc player)
          for this = (next-event sc player)
          while this
          do
          (when (and same-spellings
                     (is-tied-to this))
            ;; 24.3.11
            (unless (pitch-or-chord last)
              (error "slippery-chicken::check-ties (~a): <this> is tied-to ~
                          but <last> has no pitch.~%THIS:~%~a~%LAST:~%~a"
                     player this last))
            (setf (pitch-or-chord this) (clone (pitch-or-chord last)))
            (when (written-pitch-or-chord this)
              (setf (written-pitch-or-chord this) 
                    (clone (written-pitch-or-chord last)))))
          (when (or (and (is-tied-from last)
                         (not (is-tied-to this)))
                    (and (is-tied-to this)
                         (not (is-tied-from last))))
            (warn "slippery-chicken::check-ties: bad tie, ~a bar ~a" 
                  player (next-event sc nil)))
          (setf last this))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/rebar
;;; FUNCTION
;;; rebar:
;;;
;;; See documentation in piece class method. Don't confuse with re-bar method.
;;; 
;;; RETURN VALUE  
;;; always t
;;; 
;;; SYNOPSIS
(defmethod rebar ((sc slippery-chicken) 
                  &optional instruments-hierarchy rebar-fun)
;;; ****
  (rebar (piece sc) (if instruments-hierarchy
                        instruments-hierarchy
                        (instruments-hierarchy sc))
         rebar-fun)
  ;; got to renumber the bars
  (update-slots sc)
  ;; got to call this here rather than in piece class
  (update-write-time-sig2 (piece sc))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod section-num-rthm-seqs ((sc slippery-chicken) section)
  (num-rthm-seqs (get-data (list section (first (instruments-hierarchy sc)))
                           (piece sc))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 26/4/10: called automatically from cmn-display and init

(defmethod cleanup-rest-bars ((sc slippery-chicken) 
                              &optional start-bar end-bar players)
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (unless players
    (setf players (players sc)))
  (unless (listp players)
    (setf players (list players)))
  (loop for player in players do
       (loop for bar-num from start-bar to end-bar 
          for bar = (get-bar sc bar-num player)
          do
          (when (all-rests? bar)
            (force-rest-bar bar))))
  t)
            

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 28/1/11: make sure that every bar in the piece has the same time signature
;;; for each instrument in the ensemble
;;; ****m* slippery-chicken/check-time-sigs
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
(defmethod check-time-sigs ((sc slippery-chicken))
;;; ****
  (loop for bar-num from 1 to (num-bars sc) 
     for bars = (get-bar sc bar-num) ;; gets bars for all players
     for ts1 = (get-time-sig (first bars))
     do
     (loop for pbar in (rest bars) do
          (unless (time-sig-equal ts1 (get-time-sig pbar))
            (error "slippery-chicken::check-time-sigs: time signatures ~
                    are not the same at bar ~a" bar-num)))))
         

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Mon Apr  2 11:15:19 2012 -- whether a player plays more than one
;;; instrument 
;;; ****m* slippery-chicken/player-doubles
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
(defmethod player-doubles ((sc slippery-chicken) player)
;;; ****
  (let ((player-obj (get-data player (ensemble sc))))
    (unless player-obj
      (error "slippery-chicken::player-doubles: can't get player ~a" player))
    (doubles player-obj)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/get-starting-ins
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
(defmethod get-starting-ins ((sc slippery-chicken) player) ; symbol
;;; ****
  (let ((player-obj (get-data player (ensemble sc)))
        (ins-ref nil))
    (when (doubles player-obj)
      (setf ins-ref (get-first-for-player
                     (instrument-change-map sc)
                     player))
      (unless ins-ref
        (error "piece::get-starting-ins: ~a doubles, enter data into ~
                instrument-change-map"
               player)))
    ;; returns an instrument object
    (player-get-instrument player-obj 
                           ins-ref nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;  lilypond
;;; ****m* slippery-chicken/write-lp-data-for-all
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
;;; T
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defmethod write-lp-data-for-all ((sc slippery-chicken) 
                                  &key
                                  (base-path "/tmp/")
                                  start-bar end-bar (paper "a4") landscape
                                  ;; if a list, then these are the enharmonic
                                  ;; corrections
                                  (respell-notes t) 
                                  ;; automatically add clefs to instruments who
                                  ;; read more than one? 
                                  (auto-clefs t)
                                  (staff-size 14)
                                  ;; parts will always be transposed but score
                                  ;; can be in in C or not
                                  (in-c nil)
                                  (barline-thickness 0.5)
                                  (top-margin 10)    ; mm
                                  (bottom-margin 10) ; mm
                                  (left-margin 20)   ;mm
                                  (line-width 17)    ;cm
                                  (page-nums t)
                                  ;; print every bar number unless
                                  ;; multi-bar-rest?
                                  (all-bar-nums nil)
                                  ;; this has to be T if we're going to get
                                  ;; letters in the parts--but CMN printing
                                  ;; will have all parts all letters too
                                  ;; thereafter 
                                  (rehearsal-letters-all-players t)
                                  ;; set to t if using bartok pizz and
                                  ;; othersigns  
                                  (use-custom-markup nil)
                                  (rehearsal-letters-font-size 18)
                                  (lp-version "2.14.2") ;"2.12.3")
                                  ;; 24.7.11 (Pula) barlines through whole
                                  ;; staff group or just a stave
                                  (group-barlines t)
                                  ;; 5.11.11 set to t if you want lilypond to
                                  ;; optimize page breaks for page turns in
                                  ;; parts 
                                  (page-turns nil)
                                  ;; MDE Sat Mar 10 16:52:31 2012 
                                  (process-event-fun nil)
                                  ;; MDE Mon Apr 16 16:08:36 2012 -- added so
                                  ;; that we can write a subset of players
                                  ;; into the score (e.g. leave out a computer
                                  ;; part). If nil all players will be written.
                                  (players nil)
                                  ;; minimum rest necessary to do a page turn;
                                  ;; something like a time signature e.g. (2 1)
                                  ;; would mean we need a min. of 2 whole rests
                                  (min-page-turn '(2 1))
                                  ;; sim to rehearsal letters
                                  (tempi-all-players t))
;;; ****
  (declare (special cl-user::+slippery-chicken-src-path+))
  (when (and (numberp start-bar) (numberp end-bar) (>= start-bar end-bar))
    (error "slippery-chicken::write-lp-date-for-all: start-bar = ~a, ~
            end-bar = ~a???" start-bar end-bar))
  ;; MDE Mon Apr 16 16:19:47 2012 -- works when players is NIL also
  (unless (every #'(lambda (p) (member p (players sc))) players)
    (error "slippery-chicken::write-lp-data-for-all: players argument ~
            contains ~%player symbol(s) not in the ensemble: ~a" players))
  (let* ((path (trailing-slash base-path))
         ;; MDE Mon Apr 16 16:40:41 2012 -- now we have the players argument,
         ;; we have to put them in the same order as the ensemble and adjust the
         ;; staff-groupings locally to reflect any missing players
         (playrs (if players
                     (remove-if-not #'(lambda (x) (member x (players sc)))
                                    players)
                     (players sc)))
         ;; MDE Mon Apr 16 16:50:20 2012 -- adjust staff-groupings
         (staff-grping
          (let* ((grpsa (split-into-sub-groups (players sc)
                                               (staff-groupings sc)))
                 (grpsb (loop for sg in grpsa collect
                             (remove-if-not #'(lambda (x) (member x playrs))
                                            sg))))
            (loop for sg in grpsb for sgl = (length sg)
                 ;; don't try and create groups of zero players
               unless (zerop sgl) collect sgl)))
         ;; MDE Fri Dec  9 19:33:28 2011 -- replace spaces with hyphens so good
         ;; for file names  
         ;; MDE Fri Apr  6 12:46:27 2012 -- and remove ' too
         (title-hyphens (string-downcase
                         (remove
                          #\'
                          (substitute #\- #\  (title sc)))))
         (def-file (format nil "~a-def.ly" title-hyphens))
         (staff-group (if group-barlines "StaffGroup" "ChoirStaff"))
         (players-strings
          (loop for player in playrs
             ;; lilypond has trouble with variable names containing - or _
             collect (remove #\_ 
                             (remove #\- 
                                     (string-downcase (string player))))))
         (def-file-path (concatenate 'string path def-file)))
    (labels ((no-header-footer (stream)
               (format stream 
                       "~%\\header {~%  title =\"~a\" ~%  tagline = ##f~%  ~
                         composer = ~a~%}"
                       (title sc)
                       (if (composer sc) 
                           (format nil "\"~a\"" (composer sc))
                           "##f")))
             (new-voice (pname player stream &optional include-name) 
               ;; pname must be the same as the file name we'll write with the
               ;; notes (+ .ly) so no - or _
               (let* ((ins (get-starting-ins sc player)))
                 (format stream "~%~a = \\new Voice " pname)
                 (when page-turns
                   (princ "\\with { \\consists \"Page_turn_engraver\" }"
                          stream))
                 (princ " {" stream)
                 (when (staff-name ins)
                   (format stream " ~%  ~a"
                           (lp-set-instrument (staff-name ins))))
                 (when (staff-short-name ins)
                   (format stream "~%  ~a ~%"
                           (lp-set-instrument (staff-short-name ins) t)))
                 (princ "  \\compressFullBarRests" stream)
                 ;; change the thickness of the barlines globally
                 (format stream "~&  \\override Score.BarLine ~
                                 #'hair-thickness = #~a" barline-thickness)
                 (when page-turns
                   (format stream "~%  \\set Staff.minimumPageTurnLength = ~
                                   #(ly:make-moment ~a ~a)"
                           (first min-page-turn) (second min-page-turn)))
                 (format stream "~%  \\include \"~a-~a.ly\"~%}"
                         title-hyphens (if include-name include-name pname))))
             (score-tag (pname stream &optional new-staff-group end-staff-group)
               (when new-staff-group
                 ;; 24.7.11: to avoid barlines across groups
                 (format stream "~%  \\new ~a <<" staff-group))
               (format stream "~%    \\tag #'score \\tag #'~a \\new Staff"
                       pname)
               (format stream "~%    { << \\global #(set-accidental-style ~
                      'modern-cautionary) \\~a >> }" pname)
               (when end-staff-group
                 (format stream "~%  >>")))
             (needs-transposition (player) ; symbol
               (and in-c (plays-transposing-instrument 
                          (get-data player (ensemble sc)))))
             (written-pname (pname)
               (concatenate 'string pname "Written"))
             (part (pname stream &optional (score-tag-var "music"))
               (format stream "~&\\version \"~a\"" lp-version)
               (format stream "~&\\include \"~a\"~%" def-file)
               (no-header-footer stream)
               (terpri stream)
               (princ "\\score {" stream)
               (format stream "~&  \\new ~a \\keepWithTag #'~a \\~a"
                       staff-group pname score-tag-var)
               (format stream "~%  \\layout { }~%}")))
      (when respell-notes
        (respell-notes sc respell-notes))
      (when auto-clefs
        (format t "~&Inserting automatic clefs....")
        (auto-clefs sc :players playrs :verbose nil :in-c in-c
                    :delete-marks-before nil))
      (when rehearsal-letters-all-players 
        (format t "~&Setting rehearsal letters....")
        (set-rehearsal-letters sc playrs))
      (when tempi-all-players 
        (format t "~&Updating tempo of events....")
        (update-events-tempo sc playrs))
      ;; this will set the multi-bar-rest slot of the bars; NB it must come
      ;; after rehearsal letters and tempi
      (multi-bar-rests sc)
      ;; write the definitions file
      (with-open-file 
          (out def-file-path :direction :output :if-does-not-exist :create
               :if-exists :rename-and-delete)
        ;; print would print the " marks hence princ
        (princ "\\include \"english.ly\"" out)
        (format out "~%~%\\paper { ~%  #(set-paper-size \"~a\"~a)" 
                paper (if landscape " 'landscape" ""))
        (when page-turns
          (terpri out)
          (princ "  #(define page-breaking ly:page-turn-breaking)" out))
        (format out "~%  page-limit-inter-system-space = ##t")
        (unless page-nums 
          (format out "~%  print-page-number = ##f"))   
        (format out "~%  top-margin = ~a\\mm" top-margin)
        (format out "~%  bottom-margin = ~a\\mm" bottom-margin)
        (format out "~%  left-margin = ~a\\mm" left-margin)
        (format out "~%  line-width = ~a\\cm" line-width)
        ;; paper } closed here
        (format out "~%}~%~%#(set-global-staff-size ~a)~%~%" staff-size)
        (when use-custom-markup
          (format out "~%\\include \"~alilypond.ly\"~%~%"
                  cl-user::+slippery-chicken-src-path+))
        (princ "global = {" out) 
        (terpri out)
        (princ "  \\key c \\major" out)
        (terpri out)
        (princ "  \\numericTimeSignature" out)
        (terpri out)
        (princ "}" out)
        (terpri out)
        (terpri out)
        (loop for pname in players-strings
           for player in playrs do
           (when (needs-transposition player)
             (new-voice (written-pname pname) player out 
                        (concatenate 'string pname "-written")))
           (new-voice pname player out))
        (terpri out)
        (format out "~%music = {~%  <<")
        ;; write the music variable, staff groupings etc.
        ;; MDE Mon Apr 16 16:52:47 2012 -- use the adjusted staff-groupings
        (loop with groups = (copy-list staff-grping) ;(staff-groupings sc))
           with gnum = (pop groups)
           with gcount = 1
           for pname in players-strings
           ;; this must come after 'in players-strings' otherwise we crash
           for end = (= gcount gnum) do
           ;; (format t "~%~a ~a ~a" pname gcount gnum)
           (score-tag pname out (= 1 gcount) end)
           (if end
               (setf gnum (pop groups)
                     gcount 1)
               (incf gcount)))
        (format out "~%  >>~%}")
        ;; create the written parts variable
        (format out "~%written = {~%  <<")
        (loop for pname in players-strings
           for player in playrs do
           (when (needs-transposition player)
             (score-tag (written-pname pname) out)))
        (format out "~%  >>~%}"))
      ;; write the main score file
      (with-open-file
          (out 
           (concatenate 'string path
                         (format nil "_~a-score.ly" title-hyphens))
           :direction :output :if-does-not-exist :create
           :if-exists :rename-and-delete)
        (format out "~&\\version \"~a\"" lp-version)
        (format out "~%\\include \"~a\"" def-file)
        (no-header-footer out)
        (format out "~%\\score {~%  \\keepWithTag #'score ~
                   \\music")
        (format out "~%  \\layout { }~%}~%"))
      ;; write the parts
      (loop for player in playrs
         for pname in players-strings do
         (with-open-file 
             (out 
              (concatenate 'string path (format nil "~a-~a-part.ly" 
                                                 title-hyphens pname))
              :direction :output :if-does-not-exist :create
              :if-exists :rename-and-delete)
           (if (needs-transposition player)
               (part (written-pname pname) out "written")
               (part pname out))))
      ;; write the notes to individual files
      (loop for player in playrs
         for pname in players-strings do
         (write-lp-data-for-player 
          sc player 
          (concatenate 'string path (format nil "~a-~a.ly" title-hyphens pname))
          :all-bar-nums all-bar-nums
          :process-event-fun process-event-fun
          :rehearsal-letters-font-size rehearsal-letters-font-size
          :in-c in-c :start-bar start-bar :end-bar end-bar))
      ;; got to write the written (i.e. not sounding) notes for the part
      ;; can't do this in the above loop as we have to re-call auto-clefs
      ;; making sure we don't use the in-c clefs for the instrument
      (when auto-clefs
        (auto-clefs sc :players playrs :verbose nil :in-c nil
                    :delete-marks-before nil))
      (loop for player in playrs
         for pname in players-strings do
         ;; got to write the written (i.e. not sounding) notes for the part
         (when (needs-transposition player)
           (write-lp-data-for-player 
            sc player 
            (format nil "~a~a-~a-written.ly" path title-hyphens pname)
            :all-bar-nums all-bar-nums :in-c nil :start-bar start-bar
            :end-bar end-bar)))))
  t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod write-lp-data-for-player ((sc slippery-chicken) player path
                                     &key start-bar end-bar in-c
                                     ;; print every bar number unless
                                     ;; multi-bar-rest?
                                     all-bar-nums 
                                     ;; MDE Sat Mar 10 16:53:16 2012 
                                     process-event-fun
                                     rehearsal-letters-font-size)
  (unless start-bar
    (setf start-bar 1))
  (unless end-bar
    (setf end-bar (num-bars sc)))
  (with-open-file
      (out path :direction :output :if-does-not-exist :create
           :if-exists :rename-and-delete)
    (let* ((player-obj (get-data player (ensemble sc)))
           (transposing (plays-transposing-instrument player-obj))
           (ins-obj (get-starting-ins sc player))
           (clef (starting-clef ins-obj)))
      (when all-bar-nums
        (format out "~&\\override Score.BarNumber ~
                     #'break-visibility = #'#(#t #t #t)")
        ;; bar numbers centered over barline
        (format out "~&\\override Score.BarNumber #'self-alignment-X = #0"))
      ;; just write this in all parts, whether there's pedalling or not--does
      ;; no harm  
      (format out "~&\\set Staff.pedalSustainStyle=#'mixed")
      ;; 28.7.11 (Pula)
      (format out "~&\\autoBeamOff")
      (format out "~&\\clef ~a" (string-downcase (format nil "~a" clef)))
      (loop for bar-num from start-bar to end-bar
         for rsb = (get-bar sc bar-num player)
         for lp-data = (get-lp-data rsb (or in-c (not transposing)) 
                                    rehearsal-letters-font-size
                                    process-event-fun)
         do
         (format out "~&% bar ~a~%" bar-num)
         (loop for data in lp-data do
              (when data
                ;;(format out "~a " data))))))
                (format out data))))))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod delete-bars-aux ((sc slippery-chicken) start-bar num-bars player
                            print)
  (loop with seq-num-bars with num-deleted until (zerop num-bars) do
       (multiple-value-bind (seq nth-bar)
           (get-sequenz-from-bar-num (piece sc) start-bar player)
         (unless seq
           (error "slippery-chicken::delete-bars-aux: couldn't get seq ~
                   at bar ~a" start-bar))
         (when print
           (print-simple seq))
         (setf seq-num-bars (num-bars seq)
               num-deleted (min num-bars (- seq-num-bars nth-bar)))
         (when (zerop num-deleted)
           (error "slippery-chicken::delete-bars-aux: num-deleted = 0!"))
         (if (= seq-num-bars num-deleted) 
             ;; delete the whole sequenz
             (delete-sequenzes (piece sc) start-bar player)
             (delete-bars seq nth-bar :num num-deleted))
         ;; have to call this here to get proper bar numbers and rthm-seq-bar
         ;; data.  
         (update-slots sc)
         ;; don't inc start-bar as bar-nums are adjusted via update-slots
         ;; (incf start-bar num-deleted)
         (decf num-bars num-deleted)
         (when print
           (format t "~%num-deleted: ~a, num-bars in seq: ~a, nth-bar: ~a, ~
                      num-bars: ~a"
                   num-deleted (num-bars seq) nth-bar num-bars))))
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 22.7.11 (Pula)
;;; all 1-based and inclusive
;;; ****m* slippery-chicken/get-events-from-to
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
(defmethod get-events-from-to ((sc slippery-chicken) player start-bar
                               start-event end-bar &optional end-event)
;;; ****
  (unless end-event
    (setf end-event (num-rhythms (get-bar sc end-bar player))))
  (let ((result '()))
    (loop for bar-num from start-bar to end-bar 
       for bar = (get-bar sc bar-num player)
       do
       (loop for e in (rhythms bar) and e-count from 1 do
            (when (or (and (> bar-num start-bar)
                           (< bar-num end-bar))
                      (and (= start-bar end-bar)
                           (>= e-count start-event)
                           (<= e-count end-event))
                      (and (/= start-bar end-bar)
                           (= bar-num start-bar)
                           (>= e-count start-event))
                      (and (/= start-bar end-bar)
                           (= bar-num end-bar)
                           (<= e-count end-event)))
              (push e result))))
    (nreverse result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* slippery-chicken/transpose-events
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
(defmethod transpose-events ((sc slippery-chicken) player start-bar
                             start-event end-bar end-event semitones
                             &key (destructively t))
;;; ****
  (let ((events (get-events-from-to sc player start-bar start-event end-bar
                                    end-event)))
    (loop for e in events do
         (transpose e semitones :destructively destructively))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod cautionary-accidental-aux ((sc slippery-chicken) bar-num note-num
                                      player value &optional written)
  (let ((note (get-note sc bar-num note-num player written)))
    (when note
      (when (event-p note)
        (setf note (if written
                       (written-pitch-or-chord note)
                       (pitch-or-chord note))))
      (when value
        (setf (show-accidental note) t))
      (setf (accidental-in-parentheses note) value))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; A cmn mark can only be applied to one note, after that, the mark will not
;;; display, so instead of storing the same mark in several notes, pass a
;;; function that creates a mark, and call that function to create a
;;; separate instance of the cmn mark for each note that it should be applied
;;; to. 
;;; 1.3.11 as marks are now all symbols, this is obsolete but keep in file for
;;; legacy purposes.
#|
(defmethod add-mark-to-notes ((sc slippery-chicken) mark-function player
                                  notes)
  (loop 
      for bar in notes 
      for bar-num-or-ref = (first bar)
      for notes = (rest bar)
      do
        (loop for n in notes do
              (add-mark-to-note sc bar-num-or-ref n player 
                                    (funcall mark-function))))
  t)
|#
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; MDE Tue Apr 17 19:56:03 2012 -- 
;;; ****m* slippery-chicken/get-section
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
(defmethod get-section ((sc slippery-chicken) reference)
;;; ****
  (get-data-data reference (piece sc)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Wed Apr 25 12:18:25 2012 

;;; ****m* slippery-chicken/get-sequenz-from-section
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
(defmethod get-sequenz-from-section ((sc slippery-chicken)
                                     section-ref player-ref seq-num) ; 1-based
;;; ****
  (let ((section (get-section sc section-ref)))
    (when section
      (get-sequenz section player-ref seq-num))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Related functions.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; MDE Sat Mar 31 09:56:33 2012 -- If any of the sc slots have defaults it's
;;; best to make them the default args here too.  But the init method also sets
;;; a couple of them in case they've been made nil and would thus cause an
;;; error. 
;;; ****f* slippery-chicken/make-slippery-chicken
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
(defun make-slippery-chicken (name &key rthm-seq-palette rthm-seq-map
                              set-palette set-map sndfile-palette 
                              tempo-map tempo-curve (snd-output-dir "/tmp/")
                              instrument-change-map 
                              instruments-write-bar-nums
                              bars-per-system-map
                              staff-groupings
                              rthm-seq-map-replacements
                              set-map-replacements
                              set-limits-low set-limits-high
                              instrument-palette ensemble 
                              rehearsal-letters (fast-leap-threshold 0.125)
                              instruments-hierarchy 
                              (title "slippery-chicken-piece") composer
                              (avoid-melodic-octaves t)
                              (pitch-seq-index-scaler-min 0.5) (warn-ties t))
;;; ****
  ;; we make the given name a global!!!
  (set name
       (make-instance 'slippery-chicken 
                      :id name
                      :title title
                      :composer composer
                      :rthm-seq-palette rthm-seq-palette
                      :rthm-seq-map rthm-seq-map
                      :rthm-seq-map-replacements rthm-seq-map-replacements
                      :set-palette set-palette 
                      :set-map set-map
                      :set-map-replacements set-map-replacements
                      :instruments-write-bar-nums instruments-write-bar-nums
                      :staff-groupings staff-groupings
                      :rehearsal-letters rehearsal-letters
                      :instrument-change-map instrument-change-map
                      :snd-output-dir snd-output-dir
                      :sndfile-palette sndfile-palette
                      :instrument-palette instrument-palette
                      :tempo-map tempo-map
                      :tempo-curve tempo-curve
                      :bars-per-system-map bars-per-system-map
                      :ensemble ensemble
                      :instruments-hierarchy instruments-hierarchy
                      :set-limits-low set-limits-low 
                      :set-limits-high set-limits-high
                      :fast-leap-threshold fast-leap-threshold
                      :pitch-seq-index-scaler-min pitch-seq-index-scaler-min
                      :avoid-melodic-octaves avoid-melodic-octaves
                      :warn-ties warn-ties)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Use this function to randomly generate the <entry-points> to clm-loops

;;; ****f* slippery-chicken/random-loop-points
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
#+clm
(defun random-loop-points (outfile sndfile 
                           &key 
                           ;; the minimum number of time points for an output
                           ;; loop--number of looped sound segments is 1- this
                           (min-points 5)
                           ;; max number of time points--the actual number of
                           ;; points will be randomly chosen between these two
                           ;; numbers. 
                           (max-points 13)
                           ;; minimum duration of a loop segment--this number
                           ;; will actually be used and scaled by scalers
                           (min-dur 0.05)
                           ;; how many sets of loops should be generated
                           (num-loop-sets 20)
                           ;; scalers for the min-dur: these are all
                           ;; proportions relative to min-dur so if we have
                           ;; 13/8 in this list and min-dur of 0.05 then the
                           ;; duration for such a segment would be 0.08125.
                           ;; these will be chosen at random when calculating
                           ;; the next loop segment duration
                           (scalers '(1/1 2/1 3/2 5/3 8/5 13/8)))
;;; ****
  (let* ((snd-dur (clm::sound-duration sndfile))
         (max-scaler (loop for s in scalers maximize s))
         (max-start (- snd-dur (* min-dur (1- max-points) max-scaler)))
         (num-scalers (length scalers)))
    (with-open-file 
        (out outfile :direction :output :if-does-not-exist :create
         :if-exists :error)
      (format out "(")
      (loop 
          repeat num-loop-sets 
          for num-points = (between min-points max-points)
          for point = (random max-start)
          do
            (format out "~&(")
            (loop 
                repeat num-points
                ;; for scaler = (random-from-list scalers num-scalers)
                ;; for point = start
                do
                  (format out "~,3f " point)
                  (incf point (* min-dur
                                 (random-from-list scalers num-scalers))))
            (format out ")"))
      (format out ")"))))
                  
            
         

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; This function was first introduced in the composition "breathing Charlie"
;;; (under the name loops): see charlie-loops.lsp in that project for
;;; examples. 
;;;
;;; sndfile is the path of the file to be looped (mono) 
;;;
;;; entry-points is a list of times, in seconds, where attacks (or something
;;; significant) happen in the file.  These are used to create loop start/end
;;; points.
;;; 
;;; Be careful when doing shuffles as if, e.g., the transpositions list is more
;;; than 6 elements, shuffling will take a very long time.
;;; 
;;; The entry-points are used randomly so that any segment may start at any
;;; point and proceed to any other point (i.e. skipping intervening points,
;;; always forwards however).  There are always two segments in use at any
;;; time.  Which ones are used is selected randomly, then a transition (see
;;; Fibonacci-transitions below) from repeated segment 1 to repeated segment 2
;;; is made.  Then the next segment is chosen and the process is repeated
;;; (i.e. from previous segment 2 to new segment) until we go above
;;; max-start-time.
;;; 
;;; Fibonacci-transitions are first shuffled then made into a circular
;;; list.  Then they are expanded to create the transpositions (each
;;; number becomes a series of 1s and 0s--length is the number
;;; itself--with a transition from all 0s to all 1s: 
;;; e.g. (fibonacci-transition 20) -> (0 0 0 0 1 0 0 1 0 1 0 1 0 1 0 1 0 1 1 1)
;;; This is then used to select one or the other of the current two segments.
;;;
;;; The transpositions are simply randomly permutated and selected.

;;; ****f* slippery-chicken/clm-loops
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
#+clm
(defun clm-loops (sndfile entry-points &key
                                       (max-perms 1000)
                                       (fibonacci-transitions '(34 21 13 8))
                                       (max-start-time 60.0)
                                       (output-dir "./")
                                       (srate clm::*clm-srate*)
                                       (data-format clm::*clm-data-format*)
                                       (channels 1)
                                       ;; semitones
                                       (transpositions '(0))
                                       ;; added 31/7/05 to vary the order of
                                       ;; entry points, transpositions and
                                       ;; fibonacci-transitions (could be 0!)
                                       (num-shuffles 1) 
                                       (suffix "")
                                       (src-width 5))
;;; ****
  (format t "~&num-shuffles: ~a" num-shuffles)
  (let* ((perms (flatten 
                 ;; inefficient-permutations will always return :max results no
                 ;; matter what the first argument
                 (inefficient-permutations (length entry-points)
                                           :max max-perms)))
         (shuffled (multi-shuffle-with-perms entry-points num-shuffles))
         (srcs (loop for i in transpositions collect (semitones i)))
         (transp-perms (make-cscl
                        (multi-shuffle-with-perms
                         (flatten 
                          (permutations (length transpositions)))
                         num-shuffles)))
         (fts (make-cscl 
               (multi-shuffle-with-perms fibonacci-transitions num-shuffles)))
         (transition nil)
         (output-file (format nil "~a~a-loops-from-~a-~a.wav" 
                              output-dir (pathname-name sndfile) 
                              (secs-to-mins-secs (first entry-points) 
                                                 :same-width t
                                                 :separator "m")
                              suffix))
         (start 0.0)
         (end 0.0)
         (start1 0.0)
         (start2 0.0)
         (end1 0.0)
         (end2 0.0)
         (src 0.0)
         (src1 1.0)
         (src2 (nth (get-next transp-perms) srcs))
         (duration 0.0)
         (output-start 0.0)
         (current-perm 0))
    (labels ((get-entry
                 ()
               (let ((this (nth (mod current-perm max-perms) perms))
                     (next (nth (mod (1+ current-perm) max-perms) perms)))
                 (if (= this next)
                     (progn
                       (incf current-perm)
                       (get-entry))
                   (sort (list (nth this shuffled)
                               (nth next shuffled))
                         #'<))))
             (get-entries ()
               (let ((entry (get-entry)))
                 (setf start1 (first entry)
                       end1 (second entry))
                 ;; so this inc happens only once during selection of the two
                 ;; segments i.e. start1 end1 this time is start2 end2 last
                 ;; time. 
                 (incf current-perm)
                 (setf entry (get-entry)
                       start2 (first entry)
                       end2 (second entry)))))
      (format t "~%Output file will be ~a~%" output-file)
      (clm::with-sound 
          (:scaled-to .99 :play nil :output output-file :channels channels
                      :srate srate
                      :data-format data-format
                      :statistics t) 
        (loop while (<= output-start max-start-time)
            do
              (get-entries)
              (format t "~%~%seg1 [time (nth entry point)]: ~a (~a) -> ~a (~a)~
                           ~%seg2:                          ~a (~a) -> ~a (~a)"
                      start1 (position start1 entry-points)
                      end1 (position end1 entry-points)
                      start2 (position start2 entry-points)
                      end2 (position end2 entry-points))
              (setf transition (fibonacci-transition (get-next fts))
                    src1 src2
                    src2 (nth (get-next transp-perms) srcs))
              (loop 
                  for tr in transition 
                  while (<= output-start max-start-time)
                  do
                    ;; transition is a list of 0s and 1s
                    (if (zerop tr)
                        (setf src src1
                              start start1
                              end end1)
                      (setf src src2
                            start start2
                            end end2))
                    (setf duration (/ (- end start) src))
                    (format t "~%   ~a: src: ~a, dur: ~a, ~a -> ~a" 
                            output-start src duration start end)
                    (clm::samp5 sndfile output-start
                                :printing nil
                                :duration duration
                                :start start
                                :degree (nth (random 5) '(15 30 45 60 75))
                                :srt src
                                :width src-width
                                :amp-env '(0 0 3 1 97 1 100 0))
                    ;; 6/10/06: as long as amp-env above doesn't change the *
                    ;; 0.94 for duration should ensure an overlap--ok, the next
                    ;; duration might be shorter/longer than this so it won't
                    ;; perfectly overlap but it will start before this one
                    ;; finishes. 
                    (incf output-start (* 0.94 duration))))))))
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****f* slippery-chicken/clm-loops-all
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
#+clm
(defun clm-loops-all (sndfile entry-points-list 
                      &key 
                      (max-perms 1000)
                      (fibonacci-transitions '(34 21 13 8))
                      (max-start-time 60.0)
                      (output-dir "./")
                      (srate clm::*clm-srate*)
                      (data-format clm::*clm-data-format*)
                      (channels 1)
                      (do-shuffles t) ;; see clm-loops
                      ;; exclude all those loops who start before this
                      ;; number of seconds. 
                      (start-after -1.0)
                      (stop-after 99999999.0)
                      (suffix "")
                      ;; semitones
                      ;; 6/10/06: using just one list of transpositions passed
                      ;; onto clm-loops created the same tone structure for
                      ;; every file generated (boring).  This list will now be
                      ;; shuffled and 10 versions collected which will then be
                      ;; passed (circularly) one after the other to clm-loops.
                      (transpositions '(0))
                      (transposition-offset 0.0)
                      (src-width 5))
;;; ****
  (let* ((transps-offset (loop for st in transpositions
                             collect (+ transposition-offset st)))
         (transps-shuffled (make-cscl
                            (loop repeat 10 collect
                                  (shuffle transps-offset :reset nil)))))
    (loop for epl in entry-points-list and i from 1 do
          (when (and (> (first epl) start-after)
                     (<= (first epl) stop-after))
            (clm-loops sndfile epl :max-perms max-perms 
                       :fibonacci-transitions fibonacci-transitions
                       :num-shuffles (if do-shuffles
                                         (mod i 7)
                                       0)
                       :max-start-time max-start-time
                       :channels channels
                       :srate srate
                       :suffix suffix
                       :data-format data-format
                       :output-dir output-dir
                       :transpositions (get-next transps-shuffled)
                       :src-width src-width)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Check that the set-map and rthm-seq-map have the same number of sections,
;;; that the sections have the same names, and that each section has the same
;;; number of sequences in both maps.

(defun check-maps (set-map rthm-seq-map)
  (let* ((set-map-len (sclist-length set-map))
         (rthm-seq-map-len (sclist-length rthm-seq-map)))
    ;; are there the same number of sections?
    (unless (= set-map-len rthm-seq-map-len)
      (error "slippery-chicken::check-maps: Different number of sections ~
              in the maps: set-map ~a rthm-seq-map ~a"
             set-map-len rthm-seq-map-len))
    ;; there should be a set for every rthm-seq
    (loop 
        for i below set-map-len
        for sm-sec = (get-nth i set-map)
        for rsm-sec = (get-nth i rthm-seq-map) 
        for id-sm-sec = (id sm-sec) 
        for first-sm-sec = (data sm-sec)
        for first-rsm-sec = (data (first (data (data rsm-sec))))
        do
          (unless (id-eq id-sm-sec rsm-sec)
            (error "slippery-chicken::check-maps: Names of sections should ~
                    be the same in all maps: set-map ~a rthm-seq-map ~a"
                   id-sm-sec (id rsm-sec)))
          (cond ((and (is-ral first-sm-sec)
                      (is-ral first-rsm-sec))
                 (check-maps (data sm-sec) (data rsm-sec)))
                ((or (is-ral first-sm-sec)
                     (is-ral first-rsm-sec))
                 (error "slippery-chicken::check-maps: rthm-seq-map and ~
                         set-map must have the same recursive structure!"))
                ;; in the set-map, the references are the same for each
                ;; instrument so there's only 1 list 
                (t (let ((len-sm-sec (length (data sm-sec)))
                         ;; there's refs for each instrument in the
                         ;; rthm-seq-map 
                         (len-rsm-sec (length (data
                                               (get-nth 0 (data rsm-sec))))))
                     (unless (= len-sm-sec len-rsm-sec)
                       (error "slippery-chicken::check-maps: In section ~
                               ~a the number of references in the maps ~
                               is not equal.~
                               ~% In set-map: ~a, in rthm-seq-map: ~a" 
                              (this sm-sec) len-sm-sec len-rsm-sec))))))))
              
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun rsm-to-piece (rsm sc)
  ;; do this to reset the seq count
  (make-section-for-player nil sc nil)
  (loop for i in (data rsm) do
       (let* ((data (data i))
              (data-data (data data))
              (last-event nil)
              (last-pitch-seen nil)
              (section nil))
         ;; data has to be a ral, but the question is, is it a ral of
         ;; player-sections to be or a subsection?
         (if (is-ral (data (first data-data)))
             (progn
               (setf section (sc-change-class (rsm-to-piece data sc) 'section)
                     (data i) section
                     last-event 
                     (unless (zerop (num-bars section))
                       (get-last-event 
                        (get-last-bar section))))
               (when (pitch-or-chord last-event)
                 (setf last-pitch-seen (pitch-or-chord last-event))))
             (progn 
               ;; MDE Thu Dec  8 21:39:07 2011 -- print section ID
               (format t "~&******* section ~a" (full-ref data))
               (setf (data i) (sc-change-class data 'section)
                     (data (data i)) 
                     ;; 7/3/07: we do this convoluted double loop to ensure
                     ;; that we get-notes for the player in the order specified
                     ;; in the given hierarchy.
                     (loop 
                        with result = (ml nil (length data-data))
                        for pl in (instruments-hierarchy sc)
                        do
                        (loop 
                           for player in data-data 
                           for player-name = (first (last (this player)))
                           for player-section = 
                           (when (eq player-name pl)
                             (format t "~&Getting notes for ~a" player-name)
                             (make-section-for-player player sc last-event
                                                      last-pitch-seen))
                           ;; collect player-section
                           for i from 0
                           do
                           (when player-section
                             (setf (nth i result) player-section)
                             (unless (zerop (num-bars player-section))
                               ;; last-event is used for ties over to the
                               ;; beginning of bar 1 in a new seq
                               (setf last-event
                                     (get-last-event 
                                      (get-last-bar player-section)))
                               (when (pitch-or-chord last-event)
                                 ;; this one is used to avoid 8ves
                                 (setf last-pitch-seen 
                                       (pitch-or-chord last-event))))))
                        finally (return result)))))))
  rsm)
            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Adds postscript code to specific pages in a file.
;;; e.g. (add-ps-to-file "file.eps" '((1 "blah") (4 "foo") (3 "bar"))) 
;;; where the strings will be added to pages 1, 4 and 3, just after the
;;; "%%Page: x y" line.  Of course, the strings should be legal postscript
;;; code, not just "blah blah".  The pairs are sorted into ascending page order
;;; first so that the file only has to be searched once when looking for the
;;; pages. 

(defun add-ps-to-file (file page-code-pairs)
  (let ((tmp-file (format nil "~aadd-ps-to-file.tmp" 
                          (directory-namestring file))))
    (with-open-file
        (out tmp-file :direction :output :if-does-not-exist :create
         :if-exists :error)
      (with-open-file
          (in file :direction :input :if-does-not-exist :error)
        (loop 
            with sorted = (sort (copy-list page-code-pairs)
                                #'(lambda (x y) (< (first x) (first y))))
            with page 
            with page-num
            with page-string
            with stop
            for line = (read-line in nil nil nil) 
            for line-num from 1
            while line do
              (unless page
                (when sorted
                  (setf page (pop sorted)
                        page-num (first page)
                        page-string (format nil "%%Page: ~a" page-num)
                        stop (length page-string))))
              (format out "~a~%" line)
              (when page
                (when (and (> (length line) stop)
                           (string= page-string line :end2 stop))
                  (format out "~&%% Code added by add-ps-to-file")
                  (format t "~&Adding postscript code to page ~a~%"
                          page-num)
                  (loop for ps in (rest page) do
                        (format out "~&~a~%" ps))
                  (setf page nil)))
            finally (when sorted
                      (error "slippery-chicken::add-ps-to-file: ~
                              Couldn't find page ~a"
                             page-num)))))
    (delete-file file)
    (rename-file tmp-file file)
    t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ps-text (x y text &key (font "Courier") (font-size 10))
  (format nil "~&/~a findfont ~a scalefont setfont ~%~a ~a newpath moveto ~
               ~%(~a) show ~%"
          font font-size x y text))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Grace notes have a fixed duration as defined by the rhythm class
;;; member grace-note-duration.  We subtract this amount from the
;;; non grace-note rhythm preceding the grace note(s). Of course, if
;;; the piece/section/sequence begins with grace notes, we have to add
;;; an offset to all the notes to make time for these.

(defun handle-grace-notes (voices)
  (let* ((max-beg-grace-notes (grace-notes-at-beg voices))
         ;; just get the standard grace-note duration
         (grace-note-dur (grace-note-duration (make-rhythm 1)))
         (offset (* grace-note-dur max-beg-grace-notes)))
    ;; the grace notes at the beginning have to be handled separately because
    ;; they are dependent on the other voices.
    (handle-opening-grace-notes voices max-beg-grace-notes grace-note-dur)
    (loop 
        for voice in voices
                     ;; start after the opening grace notes
        for index = (voice-grace-notes-at-beg (first voice)) ;; first rthm-seq
                    ;; each voice is a list of rthm-seqs which in turn is a
                    ;; list of events. we want to process a flat list of events
                    ;; per voice so need to flatten it first then rebuild the
                    ;; list afterwards. 
        for lengths = (get-sublist-lengths voice t)
        with next-grace-note ;; these are indices only, not the events
        with next-non-grace-note
        with num-grace-notes
        with num-events
        with decrement
        with previous
        do
          ;; we really don't need separate lists for rthm-seqs...
          (setf voice (flatten voice)
                num-events (length voice))
          ;; (print (last voice))
          (loop until (>= index num-events) do
                (setf next-grace-note (find-next-grace-note
                                       voice index nil nil)) ; no warning
                (unless next-grace-note
                  (return))
                ;; the first normal note after the grace note(s)
                (setf next-non-grace-note (find-next-non-grace-note
                                           voice next-grace-note nil))
                (unless next-non-grace-note
                  (warn "slippery-chicken::handle-grace-notes: ~
                         Grace notes seem to end the section...! ~
                         (index = ~a, num-events = ~a, next-grace-note = ~a)"
                        index num-events next-grace-note)
                  (return))
                (setf num-grace-notes (- next-non-grace-note 
                                         next-grace-note)
                      previous (nth (1- next-grace-note) voice)
                      decrement (* grace-note-dur num-grace-notes))
                ;; decrease the duration of the note before the grace
                ;; notes. Perhaps this should only happen if the note
                ;; holds up to the next note? 
                (inc-duration previous (- decrement))
                (loop 
                    with start = 
                      (- (start-time (nth next-non-grace-note voice))
                         (* grace-note-dur num-grace-notes))
                    for i from next-grace-note 
                    for grace-note = (nth i voice)
                    repeat num-grace-notes 
                    do 
                      (setf (start-time grace-note) start
                            (end-time grace-note) (+ start grace-note-dur)
                            (duration-in-tempo grace-note) grace-note-dur
                            (compound-duration-in-tempo grace-note)
                            grace-note-dur)
                      (incf start grace-note-dur))
                (setf index next-non-grace-note))
          ;; put the flattened voice back into rthm-seqs
          (setf voice (split-into-sub-groups voice lengths)))
    ;; now we've done the grace notes, we have to offset every event to
    ;; make room for the opening grace-notes
    (unless (zerop max-beg-grace-notes)
      (loop for voice in voices do
            (loop for rs in voice do
                  (loop for event in rs do
                        (incf (duration-in-tempo event) offset)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; This only works for grace notes that open a piece (i.e. not a
;;; section or sequence) as it will set start times beginning at 0.
;;;
;;; max-grace-notes is the number of grace notes at the beginning of
;;; the voice with the most (at the beginning).

(defun handle-opening-grace-notes (voices max-grace-notes grace-note-dur)
  (loop 
    ;; with total-offset = (* max-grace-notes grace-note-dur)
      for voice in voices 
                   ;; each voice is a list of rthm-seqs so just get the first
      for rthm-seq1 = (first voice)
      for opening-grace-notes = (voice-grace-notes-at-beg rthm-seq1)
      for wait = (- max-grace-notes opening-grace-notes)
      for offset = (* grace-note-dur wait)
      do
        (loop for event in rthm-seq1 repeat opening-grace-notes do
              (unless (is-grace-note event)
                (error "~a~%slippery-chicken::handle-opening-grace-notes: ~
                        Not a grace note!" event))
              (setf (start-time event) offset)
              (incf offset grace-note-dur))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Returns the max number of grace notes that are at the beginning of the
;;; voices.  voices is one list of rthm-seqs (a list of events) for each voice
;;; in the piece.

(defun grace-notes-at-beg (voices)
  (loop for voice in voices maximize
        (voice-grace-notes-at-beg (first voice))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Returns the number of grace notes at the beginning of a list of events.
(defun voice-grace-notes-at-beg (events)
  (loop 
      with grace-notes = 0
      for event in events do
        (if (is-grace-note event)
            (incf grace-notes)
          (return grace-notes))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun count-sequence-refs (thing)
  (let ((count 0))
    (loop 
       for sec in (data thing) 
       for data = (data sec)
       do
       (incf count
             (if (is-ral data)
                 (count-sequence-refs data)
                 (length data))))
    count))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun doctor-set-limits-env (env num-sequences)
  ;; MDE Mon Apr  9 13:11:25 2012 
  (unless (> num-sequences 1)
    (error "slippery-chicken::doctor-set-limits-env: Can't apply set ~
            limits envelopes ~%to a piece with only one sequence."))
  (let ((stretched (new-lastx env num-sequences)))
    ;; 14/8/07 first x always needs to be 1
    (setf (first stretched) 1)
    (loop for x in stretched by #'cddr and y in (cdr stretched) by #'cddr
       collect
       ;; convert notes or MIDI note numbers to degrees so that we can
       ;; interpolate.  Note degrees are in cm::*scale* so this is not the same
       ;; as MIDI notes.
       x collect
       (if (numberp y)
           (midi-to-degree (floor y))
           (note-to-degree y)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun get-set-limit-aux (limits-al instrument seq-num)
  ;; (print seq-num)
  (let ((ins-curve (get-data instrument limits-al nil)))
    (when ins-curve
      (let ((degree (interpolate seq-num (data ins-curve))))
        (make-pitch (degree-to-note degree))))))
    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun count-events-before-max-start (events max-start)
  ;; (format t "count-events-before-max-start: ~a~%~a" max-start events)
  (loop 
      with result = 0
      for event in events do
        (if (listp event)
            (incf result (count-events-before-max-start event max-start))
          (when (<= (start-time event) max-start)
            (incf result)))
      finally (return result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; events is a nested list as return by get-events-with-src.
;;; NB not called from anywhere (not needed after all).

(defun rm-events-after-max-start (events max-start-time)
  (loop for voice in events collect
        (loop for rs in voice collect
              (loop for event in rs 
                  unless (> (start-time event) max-start-time)
                  collect event))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; From the rthm-seq, pitch-seq, set and hint-pitch, get the current
;;; instrument and then notes for this seq.  With the notes and the rthm-seq,
;;; promote the latter to a sequence using the notes (this involves nothing
;;; more than changing the rhythm instances in the rthm-seq-bars of the
;;; rthm-seq to event instances, adding the pitch or chord information).

(defun sc-make-sequenz (rthm-seq instrument set pitch-seq hint-pitch 
                        player player-section-ref seq-num
                        ;; this is actually an event, not a pitch or chord, and
                        ;; could be nil
                        last-note-previous-seq
                        slippery-chicken global-seq-num instrument-change
                        ;; this should always be the last pitch the instrument
                        ;; played, no matter how long ago
                        last-pitch)
  ;; (print "entering sc-make-sequenz")
  (object-is-nil? rthm-seq "slippery-chicken::sc-make-sequenz" 'rthm-seq)
  ;; (object-is-nil? pitch-seq "slippery-chicken::sc-make-sequenz" 'pitch-seq)
  ;; (print instrument-change)
  (let* ((sequenz (clone-with-new-class rthm-seq 'sequenz))
         (player-obj (when player
                       (get-player slippery-chicken player)))
         (midi-channel (if player
                           (midi-channel player-obj)
                           1))
         (microtones-midi-channel (when player
                                    (microtones-midi-channel player-obj)))
         (midi-prog (when instrument
                      (midi-program instrument)))
         (get-set-limits (and slippery-chicken player global-seq-num))
         ;; if any extra range limiting has been given for this instrument
         ;; get it here and pass it to get-notes.
         (set-limits (when get-set-limits
                       (get-set-limits slippery-chicken player 
                                       global-seq-num)))
         ;; these would have to be chords or notes once we get the
         ;; pitch-choosing algorithm going, also the midi-channel setting loop
         ;; below. 
         (notes-from-pitch-seq
          (when pitch-seq
            (get-notes pitch-seq instrument set hint-pitch (second set-limits) 
                       (first set-limits) global-seq-num 
                       last-pitch 
                       ;; MDE Mon Mar 26 13:21:29 2012
                       (if slippery-chicken
                           (pitch-seq-index-scaler-min slippery-chicken)
                           0.5)
                       (if slippery-chicken
                           (avoid-melodic-octaves slippery-chicken)
                           t))))
         (notes (my-copy-list notes-from-pitch-seq))
         #| MDE Wed Apr 18 10:24:10 2012 -- 
         (iwbns (when slippery-chicken 
         (member player 
         (instruments-write-bar-nums slippery-chicken))))
         |#
         (do-prog-changes instrument-change)
         (current-note nil)
         ;; (last-note nil)
         ;; transposition specifies how many semitones the instrument sound
         ;; above/below written pitch so we have to invert the sign of this
         ;; to get the transposition we need to write sounding pitches.
         (transpose (when instrument
                      (- (transposition-semitones instrument)))))
    (when (and transpose (zerop transpose))
      (setf transpose nil))
    ;; 31/3/10: copy over the pitch curve for info
    (when pitch-seq
      (setf (pitch-curve sequenz) (original-data pitch-seq)))
    (loop for n in notes do 
       ;; 5.2.11 this used to ignore microtonality but now sets channel
       ;; correctly 
         (if (or (pitch-p n) (chord-p n))
             (set-midi-channel n midi-channel microtones-midi-channel)
             (error "~a~%slippery-chicken::sc-make-sequenz: ~
                     Can't set MIDI channel for this object!" n)))
    ;; If there are no notes then it must be that this seq contains
    ;; only one tied (to) note so none are needed.  In that case we
    ;; have to have the last note from the previous sequence.
    (setf current-note (if notes 
                           (clone (first notes))
                           (progn
                             (unless (zerop (num-score-notes rthm-seq))
                               (unless 
                                   ;; eg when called from (cmn-display
                                   ;; rthm-seq-pallette  
                                   (and last-note-previous-seq
                                        (pitch-or-chord 
                                         last-note-previous-seq))
                                 (warn ;;"rthm-seq:~%~a  ~%last-previous-seq ~a
                                  "~%slippery-chicken::sc-make-sequenz: ~
                                     last-note-previous-seq error: should ~
                                     be a note to tie from. (rthm-seq id ~
                                     = ~a, player ~a)"
                                  ;; rthm-seq last-note-previous-seq
                                  (id rthm-seq) player)
                                 (warn "Setting to 'b4!")
                                 (setf last-note-previous-seq
                                       (make-event 'b4 'q)))
                               (clone (pitch-or-chord 
                                       last-note-previous-seq))))))
    #|
    ;; this checks that there are no ties to the first note in a seq ; ; ;
         (when (is-tied-to (get-nth-event 0 (get-bar sequenz 0 t)))
    (error "slippery-chicken::sc-make-sequenz: ~
              Tied first note of sequenz not allowed!"))
         |#
    (loop for bar in (bars sequenz) and bar-num from 1 do
       ;; first of all set all the bars to write--then change in 
       ;; sequenz::update-slots depending upon real bar num
       ;; MDE Wed Apr 18 10:22:57 2012 -- no longer do this here but in sc
       ;;(when iwbns
       ;; (setf (write-bar-num bar) t))
         (setf (player-section-ref bar) player-section-ref
               (nth-seq bar) seq-num
               (nth-bar bar) (1- bar-num))
       ;; Here the rhythms in the rthm-seq-bar are upgraded to events
         (loop for rhythm in (rhythms bar) and rthm-num from 0 do
              (let ((event (clone-with-new-class rhythm 'event)))
                ;; (print event)
                ;; 8/3/07: need to change midi programmes if an instrument
                ;; change was detected; these are stored in the event.
                (when do-prog-changes
                  ;; (format t "~&ins change! ~a ~a" player seq-num)
                  ;; add the instrument change unless this is the first seq
                  ;; (because midi-play handles all the starting program
                  ;; changes) 
                  (unless (= 1 global-seq-num)
                    (push (list midi-channel midi-prog)
                          (midi-program-changes event))
                    (when (microtonal-chords-p player-obj)
                      (push (list microtones-midi-channel midi-prog)
                            (midi-program-changes event)))
                    ;; 8/5/07: also make sure new-staff-name is added to the
                    ;; note (this makes use of new cmn code by me and
                    ;; hopefully added to main repository by Bill).
                    ;; (instrument change is registered here)
                    (setf (instrument-change event)
                          (if (staff-short-name instrument)
                              (list (staff-name instrument)
                                    (staff-short-name instrument))
                              (list (staff-name instrument)))))
                  (setf do-prog-changes nil))
                (unless (is-rest event)
                  (setf (pitch-or-chord event) 
                        (cond ((needs-new-note event)
                               (setf ;; last-note current-note
                                current-note (pop notes))
                               (unless current-note
                                 (error "~a~a~%slippery-chicken::~
                                       sc-make-sequenz: no current-note (1)!"
                                        rthm-seq pitch-seq))
                               (clone current-note))
                              ((is-tied-to event) 
                               (unless current-note
                                 (print notes-from-pitch-seq)
                                 (print event)
                                 (error "~a~a~%slippery-chicken::~
                                       sc-make-sequenz: no current-note (1)!"
                                        rthm-seq pitch-seq))
                               (clone current-note)))))
                (when transpose
                  (set-written event transpose))
                ;; MDE Thu Apr 19 12:34:52 2012 -- statistics
                (when (needs-new-note event)
                  ;; so this handles chords
                  (incf (total-degrees instrument) (get-degree event :sum t)))
                ;; (when (is-single-pitch event)
                ;;       (print (midi-channel (pitch-or-chord event))))
                (setf (nth rthm-num (rhythms bar)) event)))
       ;; MDE Thu Apr 19 10:21:07 2012 -- statistics
       ;; MDE Thu Apr 19 14:16:07 2012 -- shoudn't need this now
       ;; (gen-stats bar) 
         (unless (is-rest-bar bar)
           (incf (total-bars instrument))
           ;; we can't do total-duration here as we don't have the events'
           ;; duration-in-tempo until later...
           (incf (total-notes instrument) (notes-needed bar))))
    ;; all the notes should have been popped off by now
    (when notes
      (error "~a ~a ~%slippery-chicken::sc-make-sequenz: Didn't use all ~
              the notes!  Still have ~a left."
             rthm-seq pitch-seq (length notes)))
    ;; the marks given in the rthm-seq were not interpreted in that class,
    ;; first here when all the rhythms have been converted to events.
    ;; 19/2/07: move this method over to the rthm-seq class and call it there
    ;; (add-marks sequenz)
    ;; (print "exiting sc-make-sequenz")
    sequenz))
            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; If we get three notes whose best clef without ledger lines is not the
;;; current, change it.  If any note has only a best clef that is different to
;;; current, change it

(defun auto-clefs-handle-last-3 (last-events last-clefs note-count
                                 current-clef 
                                 &optional verbose in-c)
  ;; weird compilation bug...
  (when (event-p (first last-clefs))
    (error "~a~%slippery-chicken::auto-clefs-handle-last-3: clefs, not events!"
           last-clefs))
  (when verbose
    (format t "~&current-clef: ~a" current-clef))
  (let ((change nil)
        (change-count 0)
        (new-current-clef current-clef)
        (oldest (if (= note-count 2)
                    0
                  (1+ note-count))))
    (loop 
        with i = oldest
        with clefs with c1 ;; with event ;; with c2 
        repeat 3 do
          (setf clefs (nth i last-clefs)
                ;; remember: c is a list of two clefs
                c1 (first clefs)
                ;; c2 (second clefs)
                ;; event (nth i last-events)
                )
          (when (and c1
                     (not (equal new-current-clef c1))
                     ;; (equal new-current-clef c2)
                     ;; we need all three to do the change!
                     (or (not change)
                         (equal c1 change)))
            (incf change-count)
            (setf change c1))
          (if (= 2 i) 
              (setf i 0)
            (incf i)))
    (if (= 3 change-count)
        (let* ((e (nth oldest last-events))
               (psym (get-pitch-symbol e (not in-c))))
          (add-clef e change)
          (when verbose
            (format t "~&backup...change clef!!!: ~a before ~a"
                    change psym))
          (setf new-current-clef change))
      (loop 
          with i = oldest
          with clefs with c1 with c2 with event with psym
          repeat 3 do
            (setf clefs (nth i last-clefs)
                  ;; remember: c is a list of two clefs
                  c1 (first clefs)
                  c2 (second clefs)
                  event (nth i last-events)
                  psym (when event
                         (get-pitch-symbol event)))
            (when (and c1 psym
                       (or (and (not (equal new-current-clef c1))
                                (not (equal new-current-clef c2))
                                ;; could be we just set a clef and now c1,c2
                                ;; are no longer current so make sure we're not
                                ;; in the current clef's range before changing
                                ;; it 
                                (not (best-clef-aux 
                                      nil
                                      (if (written-pitch-or-chord event)
                                          (written-pitch-or-chord event)
                                        (pitch-or-chord event))
                                      nil current-clef verbose)))
                           (and (not (equal new-current-clef c1))
                                (not c2))))
              ;; we really need a new clef now!
              (when verbose
                (format t "~&change clef!!!: ~a before ~a" c1 psym))
              (add-clef event c1)
              ;; (cmn::cmn-get-clef c1))
              ;; this should stop us from adding multiple clefs before the
              ;; same note 
              (setf (first (nth i last-clefs)) nil
                    new-current-clef c1))))
    (when verbose
      (format t "~&change-count: ~a, last-clefs: ~a" change-count last-clefs))
    new-current-clef))
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 24.1.11: convert a tempo-curve to a tempo map, unless tempo-map is not nil,
;;; whereupon we simply return that.  Remember that the tempo curve's first
;;; element is the frequency in bars, second element is the beat rhythm, and
;;; the third is the curve itself.
;;; NB the curve should start at 0 but the map will start at bar 1
(defun tempo-curve-to-map (tempo-map tempo-curve num-bars)
  ;; MDE Thu Mar  8 15:25:33 2012 
  (unless (or tempo-map tempo-curve)
    (warn "slippery-chicken::tempo-curve-to-map: No tempo-map or tempo-curve ~
            given. ~%Using default of crotchet/quarter = 60.")
    (setf tempo-map '((1 (q 60)))))
  (when (and tempo-map tempo-curve)
    (error "slippery-chicken::tempo-curve-to-map: ~
            can't have a tempo-map and a tempo-curve; ~%only one ~
            or the other"))
  (if tempo-map
      tempo-map
      (let ((new-curve (new-lastx (third tempo-curve) num-bars))
            (beat (second tempo-curve)))
        (unless (zerop (first new-curve))
          (error "slippery-chicken::tempo-curve-to-map: ~
                  curve should start at 0: ~%~a" (third tempo-curve)))
        (loop for x from (first new-curve) to (lastx new-curve) 
           by (first tempo-curve) collect
             ;; round to the nearest bar
             (list (round x) (list beat (interpolate x new-curve)))))))
             
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MDE Thu Mar  8 15:42:33 2012 
(defun slippery-chicken-p (thing)
  (typep thing 'slippery-chicken))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; EOF slippery-chicken.lsp
