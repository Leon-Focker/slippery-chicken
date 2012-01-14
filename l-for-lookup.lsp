;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ****c* assoc-list/l-for-lookup
;;; NAME 
;;; l-for-lookup
;;;
;;; File:             l-for-lookup
;;;
;;; Class Hierarchy:  named-object -> linked-named-object -> sclist -> 
;;;                   circular-sclist -> assoc-list -> l-for-lookup
;;;
;;; Version:          1.0
;;;
;;; Project:          slippery chicken (algorithmic composition)
;;;
;;; Purpose:          Implementation of the l-for-lookup class.  The name
;;;                   stands for L-System for Lookups (L for
;;;                   Lindenmayer).  This provides an L-System
;;;                   function for generating sequences of numbers
;;;                   from rules and seeds, and then using these
;;;                   numbers for lookups into the assoc-list.  In the
;;;                   assoc list are stored groups of numbers, meant
;;;                   to represent in the first place, for example,
;;;                   rhythmic sequences.  The grouping could be as
;;;                   follows: ((2 3 7) (11 12 16) (24 27 29) and
;;;                   would mean that a transition should take place
;;;                   (over the length of the number of calls
;;;                   represented by the number of L-Sequence results)
;;;                   from the first group to the second, then from
;;;                   the second to the third.  When the first group
;;;                   is in use, then we will simple cycle around the
;;;                   given values, similar with the other groups.
;;;                   The transition is based on a fibonacci algorithm
;;;                   (see below).
;;;
;;;                   The sequences are stored in the data slot. The l-sequence
;;;                   will be a list like (3 1 1 2 1 2 2 3 1 2 2 3 2 3 3 1).
;;;                   These are the references into the assoc-list (the 1, 2, 3
;;;                   ids in the list below).
;;;
;;;                   e.g. ((1 ((2 3 7) (11 16 12)))
;;;                         (2 ((4 5 9) (13 14 17)))
;;;                         (3 ((1 6 8) (15 18 19))))
;;;
;;; Author:           Michael Edwards: m@michael-edwards.org
;;;
;;; Creation date:    15th February 2002
;;;
;;; $$ Last modified: 11:55:43 Mon Jan  2 2012 ICT
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

(eval-when (compile)
  (declaim (optimize (speed 3) (safety 1) (space 0) (debug 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :slippery-chicken)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass l-for-lookup (assoc-list)
  ((rules :accessor rules :initarg :rules :initform nil)
   (auto-check-redundancy :accessor auto-check-redundancy :type boolean
                          :initarg :auto-check-redundancy :initform nil)
   ;; what get-l-sequence returns
   (l-sequence :accessor l-sequence :type list :initform nil)
   ;; a list with the number of repetitions of each rule key in l-sequence
   (l-distribution :accessor l-distribution :type list :initform nil)
   ;; a list with the number of repetitions of each rule key in the
   ;; result of do-lookup  
   (ll-distribution :accessor ll-distribution :type list :initform nil)
   ;; in do-lookup, what to scale the values returned by.
   (scaler :accessor scaler :type number :initarg :scaler :initform 1)
   ;; sim. but added to values (after they are scaled)
   (offset :accessor offset :type number :initarg :offset :initform 0)
   ;; when the l-sequence calls a specific group, then we have to know which
   ;; sequence in that group we're now going to access to return the next
   ;; element from the circular-sclist.  Which sequence depends on how many
   ;; times a group is called (as stored in l-distribution).  This number is
   ;; used to create the fibonacci transitions from the first group to the
   ;; last.  These are what we store here as a list of circular-sclists, one
   ;; for each group (element in the assoc-list).
   (group-indices :accessor group-indices :initform nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod initialize-instance :after ((lflu l-for-lookup) &rest initargs)
  (declare (ignore initargs))
  (when (auto-check-redundancy lflu)
    ;; try different stop lengths to catch identical results
    (loop for i in '(10 20 50 100 200) do
          (check-redundant-seeds lflu i))))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
(defmethod verify-and-store :after ((lflu l-for-lookup))
  (let ((al (make-assoc-list (format nil "~a-rules" (id lflu))
                             (rules lflu))))
    ;; the data of each item in the data slot (the sequences) is a list of
    ;; references or whatever: this will be looped in a circular fashion so
    ;; create circular-sclists from this data.
    (loop for no in (data lflu) and i from 0 do
          (setf (data (nth i (data lflu)))
            (loop for group in (data no) and j from 1
                collect (make-cscl group :id (format nil "~a-~a" (id no) j)))))
    (setf (rules lflu) al)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod print-object :before ((lflu l-for-lookup) stream)
  (format stream "~%L-FOR-LOOKUP: rules: ~a~
                  ~%              l-sequence: ~a~
                  ~%              l-distribution: ~a~
                  ~%              ll-distribution: ~a~
                  ~%              group-indices: ~a~
                  ~%              scaler: ~a~
                  ~%              offset: ~a~
                  ~%              auto-check-redundancy: ~a"
          (rules lflu)
          (l-sequence lflu)
          (l-distribution lflu)
          (ll-distribution lflu)
          (group-indices lflu)
          (scaler lflu)
          (offset lflu)
          (auto-check-redundancy lflu)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod clone ((lflu l-for-lookup))
  (clone-with-new-class lflu 'l-for-lookup))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod clone-with-new-class :around ((lflu l-for-lookup) new-class)
  (declare (ignore new-class))
  (let ((assoc-list (call-next-method)))
    (setf (slot-value assoc-list 'rules) (clone (rules lflu))
          (slot-value assoc-list 'scaler) (scaler lflu)
          (slot-value assoc-list 'offset) (offset lflu)
          (slot-value assoc-list 'auto-check-redundancy)
          (auto-check-redundancy lflu)
          (slot-value assoc-list 'l-sequence) (my-copy-list (l-sequence lflu))
          (slot-value assoc-list 'l-distribution)
          (my-copy-list (l-distribution lflu))
          (slot-value assoc-list 'll-distribution)
          (my-copy-list (ll-distribution lflu))
          (slot-value assoc-list 'group-indices)
          (my-copy-list (group-indices lflu)))
    assoc-list))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* l-for-lookup/do-simple-lookup
;;; FUNCTION
;;; do-lookup does the transitioning between groups and circular returning from
;;; lists.  Sometimes we want a simple lookup procedure where a ref always
;;; returns a specific and single piece of data.
;;;
;;; N.B. scaler and offset are ignored by this method!
;;; 
;;; ARGUMENTS 
;;; 
;;; 
;;; RETURN VALUE  
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defmethod do-simple-lookup ((lflu l-for-lookup) seed stop)
;;; ****
  (reset lflu)
  (get-l-sequence lflu seed stop)
  (loop for ref in (l-sequence lflu) collect
        ;; the first data is the data of the named-object, the data of which is
        ;; a list of circular-sclists, we have simple data so we have to get
        ;; the data from the first cscl in the list.
        (data (first (data (get-data ref lflu))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* l-for-lookup/do-lookup
;;; FUNCTION
;;; do-lookup: Generate the l-seq from the rules and use it to do the
;;; Fibonacci-based transitioning lookup of values in the sequences.
;;; 
;;; ARGUMENTS 
;;; - the l-for-lookup instance
;;; - the initial seed (int, symbol etc. i.e. whatever matches a given rule)
;;; - how many items to generate (integer)
;;; - (optional default nil) a scaler to scale returned numerical values by
;;;   (will use the instances scaler slot if nil).  NB The instance's offset
;;;   slot is used to add to numerical values before returning.
;;; 
;;; RETURN VALUE  3 values:
;;; - the list returned by the lookup procedure
;;; - the distribution of the values returned by lookup
;;; - the l-sequence
;;; 
;;; EXAMPLE
#|
(let ((x (make-l-for-lookup 
          'ternary-lfl
          ;; the sequences
          ;; so the transition takes place over the 3 given lists and
          ;; i.e. from x to y to z, and each time one of these lists is
          ;; used, it will circularly return the next value.
          '((1 ((ax1 ax2 ax3) (ay1 ay2 ay3 ay4)     (az2)))
            (2 ((bx1 bx2 bx3) (by1 by2 by3 by4 by5) (bz1 bz2 bz3)))
            (3 ((cx1 cx2 cx3) (cy2 cy2 cy3)         (cz1 cz2))))
          ;; the rules
          '((1 (1 2 2 2 1 1))
            (2 (2 1 2 3 2 1))
            (3 (2 3 2 2 2 3 3))))))
  (do-lookup x 1 200))

 =>
(AX1 BX1 BX2 BX3 AX2 AX3 BX1 AX1 BX2 CX1 BX3 AX2 BX1 AX3 BX2 CX2 BX3 AX1 BX1
 AY1 BX2 CY2 BX3 AX2 AX3 BY1 BX1 BX2 AX1 AX2 AY2 BX3 BX1 BX2 AX3 AX1 BX3 AY3
 BX1 CX3 BY2 AX2 AY4 BX2 BX3 BX1 AX3 AY1 BX2 AX1 BY3 CY2 BX3 AY2 BX1 CX1 BY4
 BX2 BY5 CY3 CY2 BY1 AY3 BX3 CY2 BY2 AX2 AY4 BX1 BY3 BY4 AX3 AY1 BX2 AX1 BY5
 CX2 BY1 AY2 AY3 BY2 BY3 BX3 AX2 AY4 BY4 AY1 BY5 CY3 BY1 AY2 BY2 CY2 BY3 BY4
 BY5 CY2 CY3 BY1 AY3 BY2 CY2 BY3 AY4 AY1 BY4 BY5 BY1 AY2 AY3 BY2 AY4 BY3 CZ1
 BY4 AY1 AY2 BY5 BY1 BY2 AY3 AZ2 BY3 AY4 BZ1 CY2 BY4 AY1 BY5 CZ2 BY1 BY2 BY3
 CY3 CZ1 BY4 AY2 BY5 CZ2 BZ2 AY3 AZ2 BY1 BY2 BY3 AY4 AY1 AZ2 BY4 BZ3 BY5 AY2
 AZ2 BY1 AY3 BZ1 CZ1 BY2 AZ2 BZ2 AY4 BZ3 CY2 BY3 AZ2 BZ1 AZ2 BY4 CZ2 BZ2 AY1
 AZ2 BZ3 BY5 BZ1 AY2 AZ2 AY3 BZ2 BZ3 BZ1 AZ2 AZ2 AY4 BY1 BZ2 BZ3 AZ2 AZ2 BZ1
 AZ2 BZ2 CZ1 BZ3 AZ2 BZ1 AZ2 BZ2 CZ2 BZ3)
((CX3 1) (CX1 2) (BX1 10) (AX3 6) (BX2 10) (AX1 7) (CX2 2) (BX3 10) (AX2 7)
 (CY3 4) (BY2 10) (CY2 9) (BY3 10) (BY4 10) (AY1 9) (BY5 10) (AY2 9) (AY3 9)
 (AY4 9) (BY1 11) (CZ1 4) (BZ1 7) (AZ2 16) (BZ2 7) (CZ2 4) (BZ3 7))
(1 2 2 2 1 1 2 1 2 3 2 1 2 1 2 3 2 1 2 1 2 3 2 1 1 2 2 2 1 1 1 2 2 2 1 1 2 1 2
 3 2 1 1 2 2 2 1 1 2 1 2 3 2 1 2 3 2 2 2 3 3 2 1 2 3 2 1 1 2 2 2 1 1 2 1 2 3 2
 1 1 2 2 2 1 1 2 1 2 3 2 1 2 3 2 2 2 3 3 2 1 2 3 2 1 1 2 2 2 1 1 2 1 2 3 2 1 1
 2 2 2 1 1 2 1 2 3 2 1 2 3 2 2 2 3 3 2 1 2 3 2 1 1 2 2 2 1 1 1 2 2 2 1 1 2 1 2
 3 2 1 2 1 2 3 2 1 2 1 2 3 2 1 1 2 2 2 1 1 1 2 2 2 1 1 1 2 2 2 1 1 2 1 2 3 2 1
 2 1 2 3 2)
|#
;;; SYNOPSIS
(defmethod do-lookup ((lflu l-for-lookup) seed stop &optional scaler)
;;; ****
  (reset lflu)
  (get-l-sequence lflu seed stop)
  (get-group-indices lflu)
  (let* ((result
          (loop with scaler = (if scaler scaler (scaler lflu))
             with offset = (offset lflu)
             for group-ref in (l-sequence lflu) 
             for i = (get-position group-ref lflu)
             ;; issue the warning if it's not there! but it should be a list
             ;; of circular-sclists
             for group = (data (get-data group-ref lflu t))
             for seq-index = (get-next (nth i (group-indices lflu)))
             for this = (get-next (nth seq-index group))
             collect (if (numberp this)
                       (+ offset (* scaler this))
                       this)))
         (elements (remove-duplicates result))
         (lld (make-list (length elements))))
    (when (list-of-numbers-p elements)
      (setf elements (sort elements #'<)))
    (loop for e in elements and i from 0 do
         (setf (nth i lld) (list e (count e result))))
    (setf (ll-distribution lflu) lld)
    (values result lld (l-sequence lflu))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* l-for-lookup/reset
;;; FUNCTION
;;; 
;;; 
;;; ARGUMENTS 
;;; 
;;; 
;;; RETURN VALUE  
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defmethod reset ((lflu l-for-lookup) &optional ignore)
;;; ****
  (declare (ignore ignore))
  (loop for no in (data lflu) do
        (loop for cscl in (data no) do
              (reset cscl))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Stores a list of circular-sclists the elements of which are indices into
;;; the sequences of the groups.

(defmethod get-group-indices ((lflu l-for-lookup))
  (let ((ld (l-distribution lflu)))
    (unless ld
      (error "l-for-lookup::get-group-indices: Call get-l-sequence before ~
              this method!"))
    (setf (group-indices lflu)
          (loop 
           ;; after get-l-sequence is called we know how many times each group
           ;; will be called; this is stored in ld.
           for times-group-called in ld 
           for i from 0
           ;; we need to know how many sequences there are in this group
           ;; e.g. in 
           ;; ((1 ((2 3 7) (11 16 12)))
           ;;  (2 ((4 5 9) (13 14 17)))
           ;;  (3 ((1 6 8) (15 18 19))))
           ;; the groups are labelled 1,2,3 and each group contains 2
           ;; sequences which we'll transition between.
           for num-seqs = (length (data (get-nth i lflu)))
           ;; e.g. if we know there's 2 sequences and the group
           ;; will be called 17 times, then the first sequence
           ;; will be called 9 times, the second 8 times.
           ;; Calculate these repetitions here storing them in a
           ;; list. 
           for index-distribution = (items-per-transition times-group-called 
                                                          num-seqs)
           ;; now we can finally do the fibonacci
           ;; transitioning between the groups
           collect (if index-distribution
                       (get-group-indices-aux index-distribution)
                     (make-cscl (make-list 35 :initial-element 0)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; ****m* l-for-lookup/get-linear-sequence
;;; FUNCTION
;;; get-linear-sequence:
;;; 
;;; Instead of creating true l-seqs with rules, just use the sequences to
;;; generate a sequential list from the sequences i.e. the seed returns the
;;; first in its result list, then that's used for lookup; next time we have
;;; the seed, the second result in its list will be used (if it exists) etc..
;;; No rules (second list after id) must be in the l-for-lookup instance slot
;;; in order for this to work.  Seen very loosely, it works a bit like a
;;; first-order markov chain but without the randomness.
;;; 
;;; ARGUMENTS 
;;; - the l-for-lookup instance
;;; - the starting value used for lookup
;;; - how many results to generate
;;; - (optional) whether to reset the circular lists before proceeding
;;; 
;;; RETURN VALUE  
;;; a list of results of user-defined length
;;; 
;;; EXAMPLE
#|
(defparameter +amore-notes-progression+
  (make-l-for-lookup 'amore-notes-progressions
                     '((1 ((2)))
                       (2 ((1 3)))
                       (3 ((4 2)))
                       (4 ((6 3 5)))
                       (5 ((2 4)))
                       (6 ((4 7)))
                       (7 ((3))))
                     nil))
                     
(get-linear-sequence +amore-notes-progression+ 2 30) 
=> (1 2 3 2 1 2 3 4 5 2 1 2 3 2 1 2 3 4 6 7 3 2 1 2 3 4 3 2 1 2)
|#
;;; SYNOPSIS
(defmethod get-linear-sequence ((lflu l-for-lookup) seed stop-length
                                &optional (reset t))
;;; ****
  ;; 14/8/07: reset lists so that get-next starts at beginning and we generate
  ;; the same results each time method called with same data  
  (when reset
    (reset lflu))
  (loop 
      with current = seed 
      repeat stop-length
      collect current
      do
        ;; the circular lists are in a list of the data
        (setf current (get-next (first (data (get-data current lflu)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****m* l-for-lookup/get-l-sequence
;;; FUNCTION
;;; get-l-sequence:
;;;
;;; Return an l-sequence from the l-for-lookup object rules.  This method can
;;; be called in an l-system without sequences.  The second returned value is a
;;; count of the rule keys--in the given order--in the result list (so 1
;;; appears 0 times in the example, 2 14 times, etc.).
;;; 
;;; It seems that systems where one rule key gives all other keys as a result
;;; makes for evenly distributed results which are different for each seed.
;;; 
;;; 
;;; ARGUMENTS 
;;; - the l-for-lookup instance
;;; - the start seed to get the process running i.e. one of the rule keys
;;; - how many elements to generate
;;; 
;;; RETURN VALUE  
;;; The l-sequence as a list.
;;; 
;;; EXAMPLE
#|
(defparameter +amore-notes-progression+
  (make-l-for-lookup 'amore-notes-progressions 
                 nil
                 '((1 (2))
                   (2 (1 3))
                   (3 (4 2))
                   (4 (6 3 5))
                   (5 (2 4))
                   (6 (4 7))
                   (7 (3)))))
(get-l-sequence +amore-notes-progression+ 2 30) 
=> (2 4 2 4 7 4 2 2 4 2 4 2 4 7 4 2 2 4 4 2 4 7 4 2 2 4 2 4 2 2)
   (0 14 0 13 0 0 3)
|#
;;; SYNOPSIS
(defmethod get-l-sequence ((lflu l-for-lookup) seed stop-length)
;;; ****
  (let* ((rules (rules lflu))
         (keys (get-keys rules))
         (result '()))
    (unless (integerp stop-length)
      (warn "l-for-lookup::get-l-sequence: stop-length should be an integer ~
             but is ~a so rounding!!!" 
             stop-length)
      (setf stop-length (round stop-length)))
    (unless (> stop-length 0)
      (error "l-for-lookup::get-l-sequence: stop-length is ~a!!!" 
             stop-length))
    (unless (get-data seed rules)
      (error "l-for-lookup::get-l-sequence: seed must be in rules! : ~a" 
             seed))
    (setf result (get-l-sequence-aux rules stop-length (* stop-length 10) 0
                                     (list seed)))
    (unless result
      (error "l-for-lookup::get-l-sequence: Recursion: your rules don't ~
              yield enough results"))
    (setf result (subseq result 0 stop-length))
    (unless result 
      (error "l-for-lookup::get-l-sequence: ~a ~
              Recursion too deep!  Please check your rules: ~a"
             (id lflu) rules))
    (when keys
      (setf (l-distribution lflu) (loop for k in keys collect (count k result))
            (l-sequence lflu) result))
    (values result (l-distribution lflu))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Try to find which seeds produce identical results--not perfect as it's
;;; dependant on the stop length.
;;; Keep stop low enough to catch redundancy at the beginning of the sequence.

(defmethod check-redundant-seeds ((lflu l-for-lookup) &optional (stop 20))
  (let* ((num-rules (sclist-length (rules lflu)))
         (seeds (get-keys lflu))
         (seqs (loop for seed in seeds 
                   collect (get-l-sequence lflu seed stop))))
    (loop for seq in seqs and i from 1 do
          (loop 
              for j from i below num-rules 
              for comp = (nth j seqs)
              do
                ;; (format t "~%~a ~a" (1- i) j)
                (when (equal seq comp)
                  (warn "l-for-lookup::check-redundant-seeds ~
                         ~%In ~a: Seeds ~a and ~a produce identical ~
                         results with length ~a."
                        (id lflu) (nth (1- i) seeds) (nth j seeds) stop))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Related functions.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; SAR Fri Jan 13 17:09:19 GMT 2012: Add robodoc info

;;; ****f* l-for-lookup/make-l-for-lookup
;;; FUNCTION
;;; Create an l-for-lookup object. The l-for-lookup object uses techniques
;;; associated with Lindenmayer-systems (or L-systems) by storing a series of
;;; rules about how to produce new, self-referential sequences from the data of
;;; original, shorter sequences.
;;; 
;;; ARGUMENTS 
;;; - A symbol that will be the object's ID.
;;; - A sequence (list) or list of sequences, that serve as the initial state,
;;;   from which the permutations are to be produced.
;;; - A production rule or list of production rules, consisting of a
;;;   predecessor and a sucessor, defining how to expand and replace the
;;;   individual predecessor items.
;;;
;;; OPTIONAL ARGUMENTS
;;; - keyword argument :auto-check-redundancy. Default = NIL.
;;; - keyword argument :scaler. Factor by which to scale the values returned by
;;;   do-lookup. Default = 1. Does not modify the original data.
;;; - keyword argument :offest. Number to be added to values returned by
;;;   do-lookup (after they are scaled). Default = NIL. Does not modify the
;;;   original data. 
;;; 
;;; RETURN VALUE  
;;; Returns an l-for-lookup object.
;;; 
;;; EXAMPLE
#|
;; Create an l-for-lookup object based on the Lindenmayer rules (A->AB) and
;; (B->A), using the defaults for the keyword arguments
(make-l-for-lookup 'l-sys-a
		   '((1 ((a)))
		     (2 ((b))))
		   '((1 (1 2)) (2 (1))))

=>
L-FOR-LOOKUP:
[...]
              l-sequence: NIL
              l-distribution: NIL
              ll-distribution: NIL
              group-indices: NIL
              scaler: 1
              offset: 0
              auto-check-redundancy: NIL
ASSOC-LIST: warn-not-found T
CIRCULAR-SCLIST: current 0
SCLIST: sclist-length: 2, bounds-alert: T, copy: T
LINKED-NAMED-OBJECT: previous: NIL, this: NIL, next: NIL
NAMED-OBJECT: id: L-SYS-A, tag: NIL, 
data: (
[...]

;; A larger list of sequences, with keyword arguments specified
(make-l-for-lookup 'lfl-test
			      '((1 ((2 3 4) (5 6 7)))
				(2 ((3 4 5) (6 7 8)))
				(3 ((4 5 6) (7 8 9))))
			      '((1 (3)) (2 (3 1)) (3 (1 2)))
			      :scaler 1
			      :offset 0
			      :auto-check-redundancy nil)

|#
;;; SYNOPSIS
(defun make-l-for-lookup (id sequences rules &key (auto-check-redundancy nil)
                                                  (offset 0)
                                                  (scaler 1))
;;; ****
  (make-instance 'l-for-lookup :id id :data sequences :rules rules
                 :auto-check-redundancy auto-check-redundancy 
                 :offset offset
                 :scaler scaler))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun get-l-sequence-aux (rules stop-length max-recurse 
                           current-recurse l-values)
  ;; some rules rule out the opportunity to ever accrue stop-length results so
  ;; recursion would go on until we run out of stack space.  Avoid that.
  (cond ((> current-recurse max-recurse) nil)
        ((>= (length l-values) stop-length) l-values)
        (t (get-l-sequence-aux rules stop-length max-recurse 
                               (1+ current-recurse) 
                               (loop 
                                   for i in l-values 
                                   for tr = (data (get-data i rules))
                                   if (listp tr) append tr
                                  else collect tr)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; arg is a list like (17 17 16): do fibonacci transitions using this number
;;; of repetitions.

(defun get-group-indices-aux (group-repetitions)
  (make-cscl 
   (loop for num in group-repetitions and i from 0 
         append (fibonacci-transition num i (1+ i)))))
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****f* l-for-lookup/fibonacci
;;; FUNCTION
;;; fibonacci:
;;;
;;; Return the fibonacci numbers in a list ending at 0 that add up to a maximum 
;;; less than <max-sum>.  Returns the fibonacci number < max-sum as a second
;;; value.  
;;; 
;;; ARGUMENTS 
;;; the maximum number the fibonacci numbers should sum to
;;; 
;;; RETURN VALUE  
;;; the list of fibonacci numbers and the next in the series.
;;; 
;;; EXAMPLE
;;; (fibonacci 5000) -->
;;;    (1597 987 610 377 233 144 89 55 34 21 13 8 5 3 2 1 1 0)
;;;     4181
;;; 
;;; SYNOPSIS
(defun fibonacci (max-sum)
;;; ****
  (loop 
     ;; our result will be in descending order
     with result = '(1 0) 
     ;; the running total of sums
     with cumulative-sum = 1
     for x = 0 
     for y = 0 
     ;; the sum of our two most recent numbers.
     for sum = 0 
     do
     (setf x (first result)
           y (second result)
           sum (+ x y))
     (incf cumulative-sum sum)
     (when (> cumulative-sum max-sum)
       ;; we're not using sum this time as we're over our limit.
       ;; return can be used in loops to exit immediately
       (return (values result (1+ (- cumulative-sum sum)))))
     (push sum result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Same as fibonacci but eliminates the final 0 and 1s; can also reach max-sum
;;; rather than having to be < it.
;;; (fibonacci 20) -> (8 5 3 2 1 1 0) 20
;;; (fibonacci-start-at-2 20) -> (8 5 3 2) 18

;;; ****f* l-for-lookup/fibonacci-start-at-2
;;; FUNCTION
;;; fibonacci-start-at-2:
;;;
;;; 
;;; 
;;; DATE:
;;; 
;;; 
;;; ARGUMENTS 
;;; 
;;; 
;;; RETURN VALUE  
;;; 
;;; 
;;; EXAMPLE
#|

|#
;;; SYNOPSIS
(defun fibonacci-start-at-2 (max-sum)
;;; ****
  (multiple-value-bind
      (series sum)
      (fibonacci (+ 2 max-sum)) ; + 2 so we can hit max-sum if need be
    ;; subseq returns a sequence out of our list
    (values (subseq series 0 (- (length series) 3))
            (- sum 3))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****f* l-for-lookup/fibonacci-transition
;;; FUNCTION
;;; fibonacci-transition:
;;; 
;;; Say you want a transition between two repeating states over a period of x
;;; repetitions; this gives you a gradual break in of the second state using
;;; fibinacci relationships.
;;; fibonacci-transition-aux1 gradually decreases item1 and increases item2,
;;; this does the same but continues to increase item2 until it completely
;;; dominates. 
;;; 
;;; ARGUMENTS 
;;; - number of items you want returned in your list
;;; - (optional) item 1 (i.e. what we start with); can be any Lisp type,
;;;   including lists.  
;;; - (optional) item 2 (i.e. what we end with); can also be any Lisp type.
;;; 
;;; RETURN VALUE  
;;; a list of the transition
;;; 
;;; EXAMPLE
#|
(fibonacci-transition 35 0 1)
=> (0 0 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 1 0 1 0 1 0 1 0 1 0 1 1 0 1 1 1 1 1)
|#
;;; SYNOPSIS
(defun fibonacci-transition (num-items &optional
                                       (item1 0)
                                       (item2 1))
;;; ****
  ;; just some sanity checks
  (unless item1
    (setf item1 0))
  (unless item2
    (setf item2 1))
  ;; we use the aux1 function to first move towards more of item2, but then
  ;; again for less of item1.  The point at which this shift occurs is at the
  ;; golden section (where else?).
  (let* ((left-num (round (* num-items .618)))
         (right-num (- num-items left-num))
         ;; get the two transitions.
         (left (fibonacci-transition-aux1 left-num item1 item2))
         ;; this one will be reversed
         (right (fibonacci-transition-aux1 right-num item2 item1)))
    ;; avoid two item1s at the crossover. we use equal as it can handle number
    ;; and symbol comparison
    (when (equal (first (last right))
                 item1)
      ;; butlast returns it's argument minus the last element
      ;; e.g. (butlast '(1 2 3 4)) -> (1 2 3)
      (setf right (butlast right))
      (push item2 right))
    ;; append the two lists and return.  we can use nreverse (which is more
    ;; efficient) rather than reverse as we won't need the original version of
    ;; result
    (append left (nreverse right))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Say you want a transition between two repeating states over a period of x
;;; repetitions; this gives you a gradual break in of the second state using
;;; fibinacci relationships.
;;; <item1> is the start item, <item2> the item we want to transition towards
;;; e.g. (fibonacci-transition-aux1 21 0 1) ->
;;; (0 0 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 1 0 1 1)   
(defun fibonacci-transition-aux1 (num-items &optional
                                  (item1 0)
                                  (item2 1))
  ;; local function: usually done with flet but you can't call flet functions
  ;; recursively...
  (labels ((ftar (num) 
             ;; lisp functions can return more than one value (e.g. (floor
             ;; 3.24) usually you will only want the first value (as in the
             ;; case of floor) but we can get them all using
             ;; multiple-value-bind and friends.
             (multiple-value-bind
                   (series sum)
                 ;; returns a list of descending fib numbers and their sum--this
                 ;; will be < num-items
                 (fibonacci-start-at-2 num)
               (let ((remainder (- num sum)))
                 (if (> remainder 2)
                     ;; recursive call: what we're looking for is a descending
                     ;; list of fib numbers that total <num-items> exactly,
                     ;; hence we have to keep doing this until we've got
                     ;; num-items
                     (append series (ftar remainder))
                     ;; we're done so just store the remainder and return
                     (progn
                       (when (> remainder 0) 
                         (push remainder series))
                       series))))))
    ;; we might have something like (2 5 3 2 8 5 3 2) so make sure we sort them
    ;; in descending order.  Note that our sort algorithm takes a function as
    ;; argument.
    (fibonacci-transition-aux2 
     (stable-sort (ftar num-items) #'>)
     item1 item2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Once we have the numbers e.g. (8 5 3 2 1) we convert into indices e.g. 
;;; (0 0 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 1 1)
;;;                8         5     3   2 1
(defun fibonacci-transition-aux2 (list item1 item2)
  (let ((result '()))
    (loop for num in list do 
       ;; so each time we have 'num' items, all but one of which are item1
         (loop repeat (1- num) do 
              (push item1 result))
         (push item2 result))
    ;; we've used push so we need to reverse the list before returning
    (nreverse result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; ****f* l-for-lookup/fibonacci-transitions
;;; FUNCTION
;;; fibonacci-transitions:
;;;
;;; This allows multiple transitions 
;;; so <levels>=2 would just return 0s and 1; 3 would have 0,1,2; 1 just 0
;;; 
;;; When we use items-per-transition for generating the fibonacci
;;; transition, although the numbers returned by that function are
;;; about equal, the transition results in an uneven spread of numbers
;;; e.g.  (count-elements (fibonacci-transitions-aux 200 3)) --> (0 60
;;; 1 100 2 40) in fact we seem to get 3/5 of the first and 2/5 of the
;;; last element with the middle elements being equal.  Looking again,
;;; I see that the number of the first element + number of last is
;;; close to or the same as the number of the middle numbers, which
;;; are always about the same or equal and is total-items / 1-
;;; levels--so this is the number that will be missing from the first
;;; and last (in a 3:2 proportion). Try and balance this out (won't be
;;; perfect but pretty near).
;;; 
;;; DATE 18.2.10
;;; 
;;; ARGUMENTS 
;;; - how many items you want to generate (integer)
;;; - how many states (levels) you want to transition through (integer) or if
;;;   you give a list, the items in the list will be used to transition.
;;; RETURN VALUE  
;;; a list of transitions of length <total-items>
;;; 
;;; EXAMPLE
#|
(fibonacci-transitions 100 4) 
=>
(0 0 0 0 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 0 1 0 1 0 1 1 0 1 1 0 1 1 1 1 1 1 1
 1 1 2 1 1 2 1 1 2 1 2 1 2 2 1 2 2 1 2 2 2 2 2 2 2 2 2 3 2 2 3 2 2 3 2 3 2 3
 3 2 3 3 2 3 3 3 3 3 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3)
|#
;;; SYNOPSIS
(defun fibonacci-transitions (total-items levels)
;;; ****
  (let ((len (typecase levels 
                      (list (length levels))
                      (integer levels)
                      (t (error "l-for-lookup::fibonacci-transitions: ~
                                 levels must be a list or an integer: ~a"
                                levels)))))
    (when (<= (floor total-items len) 2)
      (error "l-for-lookup::fibonacci-transitions: can't do ~a transitions ~
              over ~a items." len total-items))
    (if (= 1 len)
        (ml 0 total-items)
        (let* ((lop-off (floor total-items len))
               (new-len (- total-items lop-off))
               (result (fibonacci-transitions-aux new-len len))
               (add-end (floor (* .618 lop-off)))
               (add-beg (- total-items new-len add-end))
               (beg (append (ml 0 (1- add-beg)) (list 1)))
               (end (ml (1- len) (1- add-end)))
               (transition (progn
                             (push (- len 2) end)
                             (append beg result end))))
          (if (listp levels)
              (loop for el in transition collect (nth el levels))
              transition)))))

(defun fibonacci-transitions-aux (total-items levels)         
  (let ((ipt (items-per-transition total-items levels)))
    (loop for num in ipt and i from 0 appending
         (fibonacci-transition num i (1+ i)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; When we know we have 50 refs to get and 4 groups, we have to make three
;;; transitions (1->2, 2->3 and 3->4) so distribute the 50
;;; evenly but with extra at the front to make up the whole 50 e.g.
;;; (items-per-transition 50 4) => (17 17 16)

(defun items-per-transition (num-items num-groups)
  (if (= 1 num-groups)
      nil
    (let ((transitions (1- num-groups)))
      (multiple-value-bind
       (floor remainder)
       (floor num-items transitions)
       (loop repeat transitions
             with plus = 1
             do
             (if (> remainder 0)
                 (decf remainder)
               (setf plus 0))
             collect (+ plus floor))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ****f* l-for-lookup/count-elements
;;; FUNCTION
;;; count-elements: count the number of times each element in the list comes
;;; forth.  Modified 15.8.10 to show items in pairs.
;;; 
;;; ARGUMENTS 
;;; a (generally flat) list of numbers or symbols (or anything that eql can
;;; match on: member's default test).
;;; 
;;; RETURN VALUE  
;;; a sorted list of two-element lists: the argument list element and the
;;; number of times it occurs.
;;; 
;;; EXAMPLE
#|
(count-elements '(1 4 5 7 3 4 1 5 4 8 5 7 3 2 3 6 3 4 5 4 1 4 8 5 7 3 2)) 
=> ((1 3) (2 2) (3 5) (4 6) (5 5) (6 1) (7 3) (8 2))
|#
;;; SYNOPSIS
(defun count-elements (list)
;;; ****
  (loop with result = '() with found = '() for e in list do
        (unless (member e found)
          (push e found)
          (push (list e (count e list)) result))
      finally (return (sort result #'(lambda (x y) (< (first x) (first y)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; EOF l-for-lookup.lsp
