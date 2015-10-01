#|
 This file is a part of legit
 (c) 2015 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.legit)

(defclass repository ()
  ((location :initarg :location :accessor location))
  (:default-initargs
   :location NIL))

(defmethod print-object ((repository repository) stream)
  (print-unreadable-object (repository stream :type T)
    (format stream "~s" (uiop:native-namestring (location repository)))))

(defun handle-init (action location remote branch)
  (ecase action
    (:error
     (error "~a is not a GIT repository." location))
    (:ignore
     NIL)
    ((:create :init)
     (git-init :directory location)
     (when (string/= branch "master")
       (git-checkout :branch (or branch "master") :orphan T)))
    ((:clone)
     (git-clone (or remote (error "REMOTE required for :CLONE."))
                :directory location
                :branch (or branch "master")))))

(defgeneric init (repository &key if-does-not-exist remote branch)
  (:method ((repository pathname) &key (if-does-not-exist :error) remote branch)
    (unless (uiop:directory-exists-p
             (relative-dir repository ".git"))
      (if if-does-not-exist
          (handle-init if-does-not-exist repository remote branch)
          (return-from init NIL)))
    (make-instance 'repository :location repository))
  (:method ((repository repository) &key (if-does-not-exist :error) remote branch)
    (unless (uiop:directory-exists-p
             (relative-dir (location repository) ".git"))
      (if if-does-not-exist
          (handle-init if-does-not-exist (location repository) remote branch)
          (return-from init NIL)))
    repository))

(defgeneric clone (from to &key branch)
  (:method ((from repository) to &key branch)
    (clone (location from) to :branch branch))
  (:method ((from pathname) to &key branch)
    (clone (uiop:native-namestring from) to :branch branch))
  (:method ((from string) (to repository) &key branch)
    (clone from (location to) :branch branch))
  (:method ((from string) (to pathname) &key branch)
    (clone from (uiop:native-namestring to) :branch branch))
  (:method ((from string) (to string) &key branch)
    (git-clone from :directory to :branch (or branch "master"))))

(defgeneric pull (repository &key)
  (:method ((repository repository) &key)
    (with-chdir (repository)
      (git-pull))))

(defgeneric checkout (repository thing &key)
  (:method ((repository repository) thing &key)
    (with-chdir (repository)
      (git-checkout :tree-ish thing))))

(defgeneric reset (repository &key to hard mixed soft)
  (:method ((repository repository) &key to hard mixed soft)
    (with-chdir (repository)
      (git-reset :paths to :hard hard :mixed mixed :soft soft))))

(defmacro git-value (repository form)
  `(with-chdir (,repository)
     (let ((*git-output* :string))
       (string-right-trim '(#\Newline) ,form))))

(defgeneric commits (repository &key)
  (:method ((repository repository) &key)
    (loop with text = (git-value repository (git-rev-list :all T))
          with stream = (make-string-input-stream text)
          for line = (read-line stream NIL NIL)
          while line
          when (string/= line "")
          collect line)))

(defgeneric current-commit (repository &key short)
  (:method ((repository repository) &key short)
    (git-value repository (git-rev-parse "HEAD" :short short))))

(defgeneric current-branch (repository &key)
  (:method ((repository repository) &key)
    (git-value repository (git-rev-parse "HEAD" :abbrev-ref T))))

(defgeneric current-message (repository &key)
  (:method ((repository repository) &key)
    (git-value repository (git-log :pretty "%B" :max-count 1))))

(defgeneric current-age (repository &key)
  (:method ((repository repository) &key)
    (unix-to-universal-time
     (parse-integer (git-value repository (git-log :pretty "%ct" :max-count 1))))))

(defgeneric remote-url (repository &key remote)
  (:method ((repository repository) &key (remote "origin"))
    (git-value repository (git-config :name (format NIL "remote.~a.url" remote)))))
