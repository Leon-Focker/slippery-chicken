;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****c* circular-sclist/afu
;;; NAME 
;;; afu
;;;
;;; File:             afu.lsp
;;;
;;; Class Hierarchy:  named-object -> linked-named-object -> sclist -> 
;;;                   circular-sclist -> afu
;;;
;;; Version:          1.0.12
;;;
;;; Project:          slippery chicken (algorithmic composition)
;;;
;;; Purpose:          AFU = Alternativ fuer Unentschiedener (a little play on
;;;                   the rather silly German political party).  This translates
;;;                   to Alternative for the Undecided. Building on the
;;;                   circular-sclist and activity-levels class, it's meant as a
;;;                   deterministic alternative to randomness.
;;;
;;; Author:           Michael Edwards: m@michael-edwards.org
;;;
;;; Creation date:    May 18th 2019
;;;
;;; $$ Last modified:  12:57:13 Sat Nov 20 2021 CET
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

(in-package :slippery-chicken)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; the data slot holds the generated numbers
(defclass afu (circular-sclist)
  ((al :accessor al :initform nil) ; the activity-levels instance
   ;; this is the activity-levels instance of the same name: which of the three
   ;; available lists of booleans we'll start at
   (start-at :accessor start-at :type integer :initarg :start-at :initform 0)
   ;; the level argument to be passed to the activity-levels' active method (0
   ;; to 10 whereby 0 and 10 would be useless for this class)
   (level :accessor level :type integer :initarg :level :initform 3)
   ;; this is the number of times we'll call the active method of the default
   ;; activity-levels object. if we pass a binlist explicitly this will be
   ;; overwritten by its length. Note that the number of numbers then generated
   ;; and stored in the data slot will be about twice the period, if the level
   ;; slot is 5. In other words we don't guarantee a specific number of results
   ;; in the data slot.
   (period :accessor period :type integer :initarg :period :initform 113)
   ;; this is a list of 1s and 0s. By default it's generated by calls to the
   ;; activity-levels' active method but could be provided by a wolfram object
   ;; or any other object/function/method that can provide such a list
   (binlist :accessor binlist :type list :initarg :binlist :initform nil)
   ;; for info only: we calculate and store the unique numbers generated by the
   ;; init-data
   (unique :accessor unique :type list :initform nil)
   ;; also for info only: the number of unique numbers generated
   (num-unique :accessor num-unique :type integer :initform -1)
   ;; an exponent to raise our numbers to before rescaling. Bear in mind that
   ;; numbers >1.0 might result in more repetition if values are then rounded to
   ;; e.g. the nearest midi pitch. See the inflate-proportionally method for
   ;; details.
   (exponent :accessor exponent :initarg :exponent :initform nil)
   ;; the minimum number we want to generate
   (minimum :accessor minimum :type number :initarg :minimum :initform 0.0)
   ;; the maximum number we want to generate
   (maximum :accessor maximum :type number :initarg :maximum :initform 1.0)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod initialize-instance :after ((a afu) &rest initargs)
  (declare (ignore initargs))
  (unless (al a)
    (setf (al a) (make-al (start-at a))))
  (if (binlist a)
      (setf (binlist a) (binlist a)) ; just to trigger setf method
      ;; use activity-levels by default
      (init-binlist a))
  (init-data a))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; called automatically but could be re-called if necessary (shouldn't
;;; be). This creates the desired list of numbers and stores them as a simple
;;; list in the data slot
(defmethod init-data ((a afu))
  (let* ((proportions (binlist-to-proportions (binlist a)))
         (data (inflate-proportionally
                proportions :invert t :expt (exponent a)
                :rescale (list (minimum a) (maximum a)))))
    ;; this also sets the unique and num-unique slots via the setf method
    (setf (data a) (copy-list data)) 
    data))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; for info/stats
(defmethod (setf data) :after (data (a afu))
  (setf (unique a) (sort (remove-duplicates data) #'<)
        (num-unique a) (length (unique a))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; if the user passes their own list of 1s and 0s then we replace the default
;;; and overwrite the period slot with the length of the given list. We then
;;; regenerate the data list
(defmethod (setf binlist) (bl (a afu))
  (setf (slot-value a 'binlist) bl
        (period a) (length bl))
  (init-data a)
  bl)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; create the list of 1s and 0s, with the activity-levels object by default
(defmethod init-binlist ((a afu))
  (reset (al a))
  (setf (binlist a) (loop repeat (period a) collect
                         (if (active (al a) (level a)) 1 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod print-object :before ((a afu) stream)
  (format stream "~%AFU: start-at: ~a, level: ~a, period: ~a ~
                  ~%     minimum: ~a, maximum: ~a, num-unique: ~a ~
                         exponent: ~a ~
                  ~%     unique: ~a ~
                  ~%     binlist: ~a"
          (start-at a) (level a) (period a) (minimum a) (maximum a)
          (num-unique a) (exponent a) (unique a) (binlist a)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod clone ((a afu))
  (clone-with-new-class a 'afu))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defmethod clone-with-new-class :around ((a afu) new-class)
  (declare (ignore new-class))
  (let ((cscl (call-next-method)))
    (setf (slot-value cscl 'al) (clone (al a))
          (slot-value cscl 'start-at) (start-at a)
          (slot-value cscl 'level) (level a)
          (slot-value cscl 'exponent) (exponent a)
          (slot-value cscl 'period) (period a)
          (slot-value cscl 'binlist) (copy-list (binlist a))
          (slot-value cscl 'minimum) (minimum a)
          (slot-value cscl 'maximum) (maxumum a))
    cscl))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****m* afu/scale
;;; DATE
;;; May 23rd 2019, Heidhausen
;;; 
;;; DESCRIPTION
;;; Scale the existing data list to be within new bounds. NB this does not check
;;; the existing data list for its maximum and minimum values, rather it uses
;;; the existing minimum and maximum slot values (which should be correct,
;;; unless something went wrong).
;;; 
;;; ARGUMENTS
;;; - the afu object
;;; - the new desired minimum (number). Default = NIL = use the current minimum
;;;   slot.
;;; 
;;; OPTIONAL ARGUMENTS
;;; - the new desired maximum (number). Default = NIL = use the current maximum
;;;   slot 
;;; 
;;; RETURN VALUE
;;; the new data list
;;; 
;;; SYNOPSIS
(defmethod scale ((a afu) new-min &optional new-max ignore1 ignore2)
;;; ****
  (declare (ignore ignore1 ignore2))
  (with-slots ((amin minimum) (amax maximum)) a
    (let* ((min (if new-min new-min amin))
           (max (if new-max new-max amax))
           (data (loop for i in (data a) collect
                      (rescale i amin amax min max))))
      (setf amin new-min
            amax new-max
            (data a) data)
      data)))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Related functions.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****f* afu/make-afu
;;; DATE
;;; May 23rd 2019, Heidhausen
;;; 
;;; DESCRIPTION
;;; Make an afu object. See https://michael-edwards.org/wp/?p=1227 for examples.
;;; 
;;; ARGUMENTS
;;; Any keyword arguments that make-instance would accept i.e. slots such as
;;; start-at, level, minimum...
;;; 
;;; RETURN VALUE
;;; An afu object
;;; 
;;; EXAMPLE
#|
(make-afu :level 3 :minimum -3 :maximum 3 :exponent .3)

AFU: start-at: 0, level: 3, period: 113 
     minimum: -3, maximum: 3, num-unique: 32 
     unique: (-3.0 -2.908942 -2.8265874 -2.7273216 -2.6483202 -2.5553133
              -2.4432077 -2.3418174 -2.2489507 -2.2196069 -2.1223445 -1.8698215
              -1.7599787 -1.7449956 -1.6306628 -1.5945365 -1.4747927 -1.3338206
              -1.1639004 -1.0286679 -0.86946154 -0.824985 -0.6775627 -0.5040059
              -0.29480958 -0.12831879 0.3039422 0.7751665 0.98014116 1.5123172
              2.3448153 3.0)
     binlist: (1 0 0 0 1 0 1 0 0 0 0 0 0 1 0 1 1 0 0 0 0 0 1 0 0 0 1 1 0 0 1 0
               0 0 1 0 1 0 0 0 0 0 0 1 0 1 1 0 0 0 0 0 1 0 0 0 1 1 0 0 1 0 0 0
               1 0 1 0 0 0 0 0 0 1 0 1 1 0 0 0 0 0 1 0 0 0 1 1 0 0 1 0 0 0 1 0
               1 0 0 0 0 0 0 1 0 1 1 0 0 0 0 0 1)
CIRCULAR-SCLIST: current 0
SCLIST: sclist-length: 408, bounds-alert: T, copy: T
LINKED-NAMED-OBJECT: previous: NIL, 
                     this: NIL, 
                     next: NIL
NAMED-OBJECT: id: NIL, tag: NIL, 
data: (-2.1223445 -1.4747927 -2.5553133 -1.4747927 -0.6775627 -2.4432077
       -2.1223445 -0.6775627 -1.8698215 -2.1223445 -1.4747927 -2.5553133
       -1.4747927 -0.6775627 -2.4432077 -2.1223445 -0.6775627 -1.8698215
       -2.1223445 -1.4747927 -2.5553133 -1.4747927 -0.6775627 -2.4432077
       -2.1223445 -0.6775627 -1.8698215 -2.1223445 -1.4747927 -2.5553133
       -1.4747927 -0.6775627 -2.4432077 -0.6775627 -1.1639004 -2.7273216
       -1.1639004 -1.8698215 -2.8265874 -1.8698215 -2.4432077 -2.2196069
...    
|#
;;; SYNOPSIS
(defun make-afu (&rest keyargs &key &allow-other-keys)
;;; ****
  (apply #'make-instance (cons 'afu keyargs)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****f* afu/binlist-to-proportions
;;; DATE
;;; May 23rd 2019, Heidhausen
;;; 
;;; DESCRIPTION
;;; From a list of an arbitrary number of 1s and 0s, create a list of
;;; corresponding proportions: Each occurrence of 1 starts a new item, with each
;;; subsequent occurence of 0 incrementing the proportion we'll collect.
;;;
;;; NB all 0s at the beginning of the list will be ignored until we see the
;;; first 1.
;;; 
;;; ARGUMENTS
;;; a simple list of 1s and 0s
;;; 
;;; RETURN VALUE
;;; a list of integers
;;; 
;;; EXAMPLE
#|
(binlist-to-proportions '(1 0 0 1 0 1 0 1 0 0 0))
--> (3 2 2 4)

;;; the final 1 has no following 0s so its 'length' is 1
(binlist-to-proportions '(1 0 0 1 0 1 0 1 0 0 0 1))
--> (3 2 2 4 1)

;;; all leading zeros ignored
(binlist-to-proportions '(0 0 0 1 0 0 1 0 1 0 1 0 0 0 1))
--> (3 2 2 4 1)
|#
;;; SYNOPSIS
(defun binlist-to-proportions (binlist)
;;; ****
  (unless (every #'(lambda (x) (or (zerop x) (= 1 x)))
                 binlist)
    (error "afu::binlist-to-proportions: argument should be a list of ~
            1s and 0s: ~a" binlist))
  (let ((count nil) ; ignore leading 0s
        (proportions '()))
    (loop for n in binlist  do
         (if (zerop n)
             (when count (incf count))
             (progn (when count (push count proportions))
                    (setq count 1))))
    ;; don't forget the last one!
    (push count proportions)
    (nreverse proportions)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****f* afu/inflate-proportionally
;;; DATE
;;; May 23rd 2019, Heidhausen
;;; 
;;; DESCRIPTION
;;; Take a list of proportions (generally integers but floating-point works too)
;;; and create a longer list, using the proportions scaled proportionally. In
;;; other words a list like '(1 2 3) will become '((1 2 3) (2 4 6) (3 6 9))
;;; i.e. internally always in proportion like the original but leading of course
;;; then to other proportions when used with permutations (see inline comments).
;;; 
;;; ARGUMENTS
;;; a simple list of proportions
;;; 
;;; OPTIONAL ARGUMENTS
;;; keyword arguments:
;;; - :invert. Whether to invert proportions (e.g. 3 becomes 1/3)  . Default =
;;;   T.
;;; - :rescale. Whether to scale the results to be within new
;;;   minima/maxima. This should be a two-element list (min. max.). Default =
;;;   '(0 1).
;;; - :highest. The highest number to use from the original list when scaling.
;;;   This limit is offered so that we don't end up with most of our numbers
;;;   down at the very bottom end of our scale. Default = 4.
;;; - :lowest. Similar to :highest but the minimum scaler we'll use.
;;;   Default = 1.
;;; - :reverse. Whether to alternate the original order with the reverse thereof
;;;   when looping through the list and applying proportional scalers. Default =
;;;   T.
;;; - :expt. An exponent to raise our results to before the rescaling process
;;;   (if used). Of course this completely changes proportions but there are
;;;   times when results are far too skewed to the bottom of the range so using
;;;   an exponent such as 0.3 
;;; 
;;; RETURN VALUE
;;; 
;;; SYNOPSIS
(defun inflate-proportionally (l &key (invert t) (rescale '(0 1))
                                   (lowest 1) (highest 4)
                                   (reverse t) (expt nil))
;;; ****
  (unless (every #'numberp l)
    (error "afu::inflate-proportionally: argument should be a list of numbers: ~
            ~a" l))
  (let* ((lr (reverse l))
         ;; only scale by unique proportions
         (rds (sort (remove-duplicates l) #'<)) ; ascending
         ;; get the list of scalers we'll use, after sorting above, we start in
         ;; the middle and fan out to either end. we also limit this to 4 (by
         ;; default: see above)
         (rdsmo (loop for i in (middle-out rds)
                   when (integer-between i lowest highest) collect i))
         ;; get all the pair permutations of the fanned scalers
         (perms (list-permutations rdsmo 2))
         ;; now turn them into actual proportions
         (pps (loop for p in perms for r = (apply #'/ p)
                 collect r))
         ;; now we've got the proportions we get all the original proportions
         ;; scaled by these
         (lrexp (loop for outer in pps and i from 0 append
                     (loop for inner in (if (or (not reverse) (evenp i))
                                            ;; this will results in some
                                            ;; sequence repetitions
                                            l lr)
                        collect (* inner outer))))
         ;; usually we'll want these proportions inverted so that we're within a
         ;; range of 0-1 i.e. 1:2:3 becomes 1:0.5:0.333 (which is essentially
         ;; the proportions reversed). Though this of course gives different
         ;; results, this might seem pointless until we use our exponent. Even
         ;; then, if rescaling the results will be the same. Still, always good
         ;; to have options.
         (lrexpi (loop for i in lrexp
                    for ii = (if invert (/ i) i)
                    collect (if expt (expt ii expt) ii)))
         (rsmin (first rescale))
         (rsmax (second rescale))
         ;; what were the min/max values we've generated before rescaling?
         (min (when rescale (apply #'min lrexpi)))
         (max (when rescale (apply #'max lrexpi))))
    ;; (print perms) (print pps) (print lrexp)
    (if rescale 
        (loop for f in lrexpi collect (rescale f min max rsmin rsmax))
        lrexpi)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EOF afu.lsp
