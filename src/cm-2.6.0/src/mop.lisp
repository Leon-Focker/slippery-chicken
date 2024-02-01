;;; **********************************************************************
;;; Copyright (C) 2003 Heinrich Taube (taube@uiuc.edu) 
;;; This program is free software; you can redistribute it and
;;; modify it under the terms of the GNU General Public License
;;; as published by the Free Software Foundation; either version 2
;;; of the License, or (at your option) any later version.
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;; **********************************************************************

;;; generated by scheme->cltl from mop.scm on 31-Jan-2024 17:13:29

(in-package :cm)

(progn
 (defclass parameterized-class (standard-class)
           ((pars :initform '() :initarg :parameters :accessor
             class-parameters)))
 (defparameter <parameterized-class>
   (find-class 'parameterized-class))
 (finalize-class <parameterized-class>)
 (values))

(defmethod validate-superclass
           ((class parameterized-class) (superclass standard-class))
  t)

(defmethod class-parameters ((obj t)) obj nil)

(defun object-parameters (obj)
  (let ((x (class-parameters (class-of obj))))
    (if (consp x)
        (mapcar #'car x)
        x)))

(progn
 (defclass io-class (standard-class)
           ((handles :initform '() :initarg :file-types :accessor
             io-class-file-types)
            (mime-type :initform nil :accessor io-class-mime-type
             :initarg :mime-type)
            (output-hook :initform nil :initarg :output-hook
             :accessor io-class-output-hook)
            (definer :initform nil :initarg :definer :accessor
             io-class-definer)
            (versions :initform nil :initarg :versions :accessor
             io-class-file-versions)))
 (defparameter <io-class> (find-class 'io-class))
 (finalize-class <io-class>)
 (values))

(defmethod validate-superclass
           ((class io-class) (superclass standard-class))
  t)

(defmethod io-class-file-types (x) x nil)

(defmethod io-class-output-hook (x) x nil)

(defmethod io-class-definer (x) x nil)

(defmethod io-class-file-versions (x) x nil)

(defun expand-inits (class args inits? other?)
  (let* ((slots (class-slots class))
         (inits (list nil))
         (tail1 inits)
         (other
          (if other?
              (list nil)
              nil))
         (tail2 other)
         (save args))
    (do ((sym nil)
         (val nil)
         (slot nil))
        ((null args)
         (if other?
             (values (cdr inits) (cdr other))
             (cdr inits)))
      (setf sym (pop args))
      (setf val
              (if (null args)
                  (error "Uneven initialization list: ~s" save)
                  (pop args)))
      (cond ((keyword? sym))
            ((and sym (symbolp sym))
             (setf sym (symbol->keyword sym)))
            (t
             (error "'~s' is not an initialization for ~s: ~s." sym
                    class save)))
      (setf slot
              (find sym slots ':key #'slot-definition-initargs :test
                    #'member))
      (if slot
          (progn
           (rplacd tail1
                   (list
                    (if inits?
                        sym
                        (slot-definition-name slot))
                    val))
           (setf tail1 (cddr tail1)))
          (if other?
              (progn
               (rplacd tail2 (list sym val))
               (setf tail2 (cddr tail2)))
              (error "'~s' is not an initialization for ~s." sym
                     class))))))

(defun slot-init-forms (o &key eval omit only key ignore-defaults)
  (loop for s in (class-slots (class-of o))
        for n = (slot-definition-name s)
        for k = (slot-definition-initargs s)
        for v = (if (slot-boundp o n)
                    (slot-value o n)
                    ':unbound-slot)
        when (and (not (eq v ':unbound-slot)) (not (null k))
                  (if omit
                      (not (member n omit :test #'eq))
                      (if only
                          (member n only :test #'eq)
                          t))
                  (not
                   (and ignore-defaults
                        (eq v (slot-definition-initform s)))))
        collect (car k)
        and
        collect (if key
                    (funcall key v)
                    (if eval
                        (quote-if-necessary v)
                        v))))

(defmethod make-load-form ((obj standard-class))
  (let ((inits (slot-init-forms obj :eval t)))
    `(make-instance
      ,(intern (format nil "<~a>" (class-name (class-of obj))) :cm)
      ,@inits)))
