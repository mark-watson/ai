(defpackage #:ai
  (:use #:cl)
  (:export #:test-function
           ;; Message struct
           #:message
           #:make-message
           #:message-role
           #:message-content
           #:message-timestamp
           #:message-metadata
           #:message-p
           ;; Message-thread struct
           #:message-thread
           #:make-message-thread
           #:message-thread-id
           #:message-thread-title
           #:message-thread-messages
           #:message-thread-created-at
           #:message-thread-metadata
           #:message-thread-p
           ;; Thread operations
           #:make-message-from-plist
           #:add-message
           #:thread-length
           #:get-message
           #:last-message
           ;; Mapping and filtering
           #:map-thread
           #:filter-thread
           #:filter-by-role
           #:filter-user-messages
           #:filter-assistant-messages
           #:transform-content
           ;; Serialization
           #:serialize-thread
           #:serialize-thread-to-file
           #:deserialize-thread
           #:deserialize-thread-from-file
           ;; Convenience functions
           #:create-thread
           #:create-chat-thread
           #:thread-to-openai-format
           #:openai-format-to-thread
           #:copy-thread
           ;; Utilities
           #:current-iso-timestamp
           #:generate-thread-id))
