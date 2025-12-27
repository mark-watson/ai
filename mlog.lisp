;;; mlog.lisp - Message Log structures for LLM message threads
;;; 
;;; This module provides:
;;; - Struct-based message and thread containers
;;; - Mapping/filtering capabilities for message threads
;;; - Serialization to text-based log format
;;; - Deserialization from text-based log format back to structs

(in-package #:ai)

;;; ============================================================================
;;; Message Structures
;;; ============================================================================

(defstruct message
  "A single message in an LLM conversation thread.
   ROLE: The role of the sender (e.g., :system, :user, :assistant)
   CONTENT: The text content of the message
   TIMESTAMP: Optional ISO-8601 timestamp string
   METADATA: Optional plist of additional key-value pairs"
  (role :user :type keyword)
  (content "" :type string)
  (timestamp nil :type (or null string))
  (metadata nil :type list))

(defstruct message-thread
  "A thread of messages representing an LLM conversation.
   ID: Unique identifier for the thread
   TITLE: Optional title for the thread
   MESSAGES: List of MESSAGE structs in chronological order
   CREATED-AT: ISO-8601 timestamp of thread creation
   METADATA: Optional plist of additional key-value pairs"
  (id (generate-thread-id) :type string)
  (title nil :type (or null string))
  (messages nil :type list)
  (created-at (current-iso-timestamp) :type string)
  (metadata nil :type list))

;;; ============================================================================
;;; Utility Functions
;;; ============================================================================

(defun current-iso-timestamp ()
  "Return current time as ISO-8601 formatted string."
  (multiple-value-bind (sec min hour day month year)
      (get-decoded-time)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D"
            year month day hour min sec)))

(defun generate-thread-id ()
  "Generate a simple unique thread ID based on time and random."
  (format nil "thread-~A-~A" 
          (get-universal-time) 
          (random 10000)))

;;; ============================================================================
;;; Message Thread Operations
;;; ============================================================================

(defun make-message-from-plist (plist)
  "Create a message from a property list with keys :role, :content, etc."
  (make-message :role (or (getf plist :role) :user)
                :content (or (getf plist :content) "")
                :timestamp (getf plist :timestamp)
                :metadata (getf plist :metadata)))

(defun add-message (thread role content &key timestamp metadata)
  "Add a new message to a thread. Returns the modified thread."
  (let ((msg (make-message :role role
                           :content content
                           :timestamp (or timestamp (current-iso-timestamp))
                           :metadata metadata)))
    (setf (message-thread-messages thread)
          (append (message-thread-messages thread) (list msg)))
    thread))

(defun thread-length (thread)
  "Return the number of messages in a thread."
  (length (message-thread-messages thread)))

(defun get-message (thread index)
  "Get the message at INDEX from THREAD. Returns nil if out of bounds."
  (nth index (message-thread-messages thread)))

(defun last-message (thread)
  "Get the last message in the thread."
  (car (last (message-thread-messages thread))))

;;; ============================================================================
;;; Mapping and Filtering
;;; ============================================================================

(defun map-thread (fn thread)
  "Apply FN to each message in THREAD, returning a new thread with mapped messages.
   FN should take a MESSAGE and return a MESSAGE (or nil to exclude)."
  (let ((mapped-messages 
          (remove nil (mapcar fn (message-thread-messages thread)))))
    (make-message-thread 
     :id (format nil "~A-mapped" (message-thread-id thread))
     :title (message-thread-title thread)
     :messages mapped-messages
     :created-at (message-thread-created-at thread)
     :metadata (message-thread-metadata thread))))

(defun filter-thread (predicate thread)
  "Return a new thread containing only messages that satisfy PREDICATE.
   PREDICATE should take a MESSAGE and return non-nil to include it."
  (let ((filtered-messages 
          (remove-if-not predicate (message-thread-messages thread))))
    (make-message-thread 
     :id (format nil "~A-filtered" (message-thread-id thread))
     :title (message-thread-title thread)
     :messages filtered-messages
     :created-at (message-thread-created-at thread)
     :metadata (message-thread-metadata thread))))

(defun filter-by-role (thread role)
  "Return a new thread containing only messages with the specified ROLE."
  (filter-thread (lambda (msg) (eq (message-role msg) role)) thread))

(defun filter-user-messages (thread)
  "Return a new thread containing only user messages."
  (filter-by-role thread :user))

(defun filter-assistant-messages (thread)
  "Return a new thread containing only assistant messages."
  (filter-by-role thread :assistant))

(defun transform-content (thread transform-fn)
  "Apply TRANSFORM-FN to the content of each message, returning a new thread.
   TRANSFORM-FN should take a string and return a string."
  (map-thread 
   (lambda (msg)
     (make-message :role (message-role msg)
                   :content (funcall transform-fn (message-content msg))
                   :timestamp (message-timestamp msg)
                   :metadata (message-metadata msg)))
   thread))

;;; ============================================================================
;;; Text Log Format Serialization
;;; ============================================================================
;;; Log format:
;;; === THREAD START ===
;;; ID: <thread-id>
;;; TITLE: <title or empty>
;;; CREATED: <timestamp>
;;; METADATA: <plist as string>
;;; --- MESSAGE ---
;;; ROLE: <role>
;;; TIMESTAMP: <timestamp or empty>
;;; METADATA: <plist as string>
;;; CONTENT:
;;; <multi-line content>
;;; --- MESSAGE ---
;;; ...
;;; === THREAD END ===

(defparameter *thread-start-marker* "=== THREAD START ===")
(defparameter *thread-end-marker* "=== THREAD END ===")
(defparameter *message-marker* "--- MESSAGE ---")
(defparameter *content-marker* "CONTENT:")

(defun serialize-plist-to-string (plist)
  "Convert a plist to a readable string representation."
  (if plist
      (with-output-to-string (s)
        (write plist :stream s :readably t))
      ""))

(defun deserialize-string-to-plist (str)
  "Parse a string back to a plist. Returns nil for empty/invalid strings."
  (when (and str (> (length str) 0))
    (ignore-errors
      (read-from-string str))))

(defun escape-content (content)
  "Escape content to handle special markers within the content."
  ;; Add a space prefix to lines that could be confused with markers
  (with-output-to-string (out)
    (with-input-from-string (in content)
      (loop for line = (read-line in nil nil)
            for first = t then nil
            while line
            do (unless first (write-char #\Newline out))
               (if (or (string= line *message-marker*)
                       (string= line *thread-end-marker*)
                       (and (>= (length line) 1) (char= (char line 0) #\Escape)))
                   (progn
                     (write-char #\Escape out)
                     (write-string line out))
                   (write-string line out))))))

(defun unescape-content (content)
  "Unescape content that was escaped during serialization."
  (with-output-to-string (out)
    (with-input-from-string (in content)
      (loop for line = (read-line in nil nil)
            for first = t then nil
            while line
            do (unless first (write-char #\Newline out))
               (if (and (>= (length line) 1) (char= (char line 0) #\Escape))
                   (write-string (subseq line 1) out)
                   (write-string line out))))))

(defun serialize-message (msg stream)
  "Serialize a single message to the stream."
  (format stream "~A~%" *message-marker*)
  (format stream "ROLE: ~A~%" (message-role msg))
  (format stream "TIMESTAMP: ~A~%" (or (message-timestamp msg) ""))
  (format stream "METADATA: ~A~%" (serialize-plist-to-string (message-metadata msg)))
  (format stream "~A~%" *content-marker*)
  (format stream "~A~%" (escape-content (message-content msg))))

(defun serialize-thread (thread &optional (stream *standard-output*))
  "Serialize a message thread to the text log format.
   If STREAM is nil, returns the serialized string."
  (let ((output-stream (or stream (make-string-output-stream))))
    (format output-stream "~A~%" *thread-start-marker*)
    (format output-stream "ID: ~A~%" (message-thread-id thread))
    (format output-stream "TITLE: ~A~%" (or (message-thread-title thread) ""))
    (format output-stream "CREATED: ~A~%" (message-thread-created-at thread))
    (format output-stream "METADATA: ~A~%" (serialize-plist-to-string (message-thread-metadata thread)))
    (dolist (msg (message-thread-messages thread))
      (serialize-message msg output-stream))
    (format output-stream "~A~%" *thread-end-marker*)
    (unless stream
      (get-output-stream-string output-stream))))

(defun serialize-thread-to-file (thread filepath)
  "Serialize a thread to a file. Creates or overwrites the file."
  (with-open-file (stream filepath :direction :output 
                                   :if-exists :supersede
                                   :if-does-not-exist :create)
    (serialize-thread thread stream)))

;;; ============================================================================
;;; Text Log Format Deserialization
;;; ============================================================================

(defun parse-header-line (line)
  "Parse a header line of format 'KEY: VALUE', returning (key . value)."
  (let ((colon-pos (position #\: line)))
    (when colon-pos
      (cons (string-trim " " (subseq line 0 colon-pos))
            (string-trim " " (subseq line (1+ colon-pos)))))))

(defun read-until-marker (stream markers)
  "Read lines from STREAM until one of MARKERS is found.
   Returns (content-lines . found-marker) or (content-lines . nil) if EOF."
  (let ((lines nil)
        (found-marker nil))
    (loop for line = (read-line stream nil nil)
          while (and line (not found-marker))
          do (if (member line markers :test #'string=)
                 (setf found-marker line)
                 (push line lines)))
    (cons (nreverse lines) found-marker)))

(defun deserialize-message (stream)
  "Deserialize a single message from the stream. 
   Assumes MESSAGE marker was just read. Returns the message or nil on error."
  (let ((role :user)
        (timestamp nil)
        (metadata nil)
        (content ""))
    ;; Read header lines until CONTENT:
    (loop for line = (read-line stream nil nil)
          while (and line (not (string= line *content-marker*)))
          do (let ((parsed (parse-header-line line)))
               (when parsed
                 (cond
                   ((string-equal (car parsed) "ROLE")
                    (setf role (intern (string-upcase (cdr parsed)) :keyword)))
                   ((string-equal (car parsed) "TIMESTAMP")
                    (setf timestamp (if (string= (cdr parsed) "") nil (cdr parsed))))
                   ((string-equal (car parsed) "METADATA")
                    (setf metadata (deserialize-string-to-plist (cdr parsed))))))))
    ;; Read content until next marker
    (let ((result (read-until-marker stream 
                                     (list *message-marker* *thread-end-marker*))))
      (setf content (unescape-content 
                     (format nil "~{~A~^~%~}" (car result))))
      ;; Return the message and what marker was found
      (values (make-message :role role
                            :content content
                            :timestamp timestamp
                            :metadata metadata)
              (cdr result)))))

(defun deserialize-thread (input)
  "Deserialize a thread from INPUT (string or stream).
   Returns the message-thread struct or nil on error."
  (let ((stream (if (streamp input)
                    input
                    (make-string-input-stream input))))
    (let ((id nil)
          (title nil)
          (created-at nil)
          (metadata nil)
          (messages nil))
      ;; Find and skip thread start marker
      (loop for line = (read-line stream nil nil)
            while line
            until (string= line *thread-start-marker*))
      ;; Read thread headers
      (loop for line = (read-line stream nil nil)
            while (and line (not (string= line *message-marker*))
                       (not (string= line *thread-end-marker*)))
            do (let ((parsed (parse-header-line line)))
                 (when parsed
                   (cond
                     ((string-equal (car parsed) "ID")
                      (setf id (cdr parsed)))
                     ((string-equal (car parsed) "TITLE")
                      (setf title (if (string= (cdr parsed) "") nil (cdr parsed))))
                     ((string-equal (car parsed) "CREATED")
                      (setf created-at (cdr parsed)))
                     ((string-equal (car parsed) "METADATA")
                      (setf metadata (deserialize-string-to-plist (cdr parsed))))))))
      ;; Read messages
      (loop 
        (multiple-value-bind (msg next-marker) (deserialize-message stream)
          (when msg (push msg messages))
          (when (or (null next-marker) 
                    (string= next-marker *thread-end-marker*))
            (return))))
      ;; Build and return the thread
      (make-message-thread :id (or id (generate-thread-id))
                           :title title
                           :messages (nreverse messages)
                           :created-at (or created-at (current-iso-timestamp))
                           :metadata metadata))))

(defun deserialize-thread-from-file (filepath)
  "Deserialize a thread from a file. Returns the message-thread or nil on error."
  (with-open-file (stream filepath :direction :input :if-does-not-exist nil)
    (when stream
      (deserialize-thread stream))))

;;; ============================================================================
;;; Convenience Functions for Common Workflows
;;; ============================================================================

(defun create-thread (&key title id metadata)
  "Create a new empty message thread."
  (make-message-thread :id (or id (generate-thread-id))
                       :title title
                       :created-at (current-iso-timestamp)
                       :metadata metadata))

(defun create-chat-thread (system-prompt &key title)
  "Create a new thread with an initial system prompt."
  (let ((thread (create-thread :title title)))
    (add-message thread :system system-prompt)
    thread))

(defun thread-to-openai-format (thread)
  "Convert a message thread to OpenAI API message format (list of plists)."
  (mapcar (lambda (msg)
            (list :role (string-downcase (symbol-name (message-role msg)))
                  :content (message-content msg)))
          (message-thread-messages thread)))

(defun openai-format-to-thread (messages &key title id)
  "Convert OpenAI API message format to a message thread."
  (let ((thread (create-thread :title title :id id)))
    (dolist (msg messages)
      (add-message thread 
                   (intern (string-upcase (getf msg :role)) :keyword)
                   (getf msg :content)))
    thread))

(defun copy-thread (thread)
  "Create a deep copy of a message thread."
  (make-message-thread
   :id (format nil "~A-copy" (message-thread-id thread))
   :title (message-thread-title thread)
   :messages (mapcar (lambda (msg)
                       (make-message :role (message-role msg)
                                     :content (message-content msg)
                                     :timestamp (message-timestamp msg)
                                     :metadata (copy-list (message-metadata msg))))
                     (message-thread-messages thread))
   :created-at (message-thread-created-at thread)
   :metadata (copy-list (message-thread-metadata thread))))
