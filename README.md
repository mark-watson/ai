# ai: a Common Lisp implementation for the ideas for the https://hybrid-ai.agency project

## Setup:

    cd ~/quicklisp/local-projects
    git clone https://github.com/mark-watson/ai.git

## Usage:

    (ql:quickload :ai)
    (ai:test-function)

## Testing message thread code

```lisp
;; Create a thread
(let ((thread (ai:create-chat-thread "You are a helpful assistant." :title "My Chat")))
  (ai:add-message thread :user "Hello!")
  (ai:add-message thread :assistant "Hi there! How can I help?")
  
  ;; Serialize to string
  (ai:serialize-thread thread nil)
  
  ;; Filter to only user messages
  (ai:filter-user-messages thread)
  
  ;; Map over messages (drop the short content Hello! message)
  (ai:map-thread (lambda (msg) 
                   (when (> (length (ai:message-content msg)) 8) msg)) 
                 thread))
```
Result of map/filter operation:

```lisp
#S(ai:message-thread
   :id "thread-3975862575-5860-mapped"
   :title "My Chat"
   :messages (#S(ai:message
                 :role :system
                 :content "You are a helpful assistant."
                 :timestamp "2025-12-27T15:16:15"
                 :metadata nil)
              #S(ai:message
                 :role :assistant
                 :content "Hi there! How can I help?"
                 :timestamp "2025-12-27T15:16:15"
                 :metadata nil))
   :created-at "2025-12-27T15:16:15"
   :metadata nil)
```

## Message thread documentation

Message log library:

### Structures:

- message - Holds role, content, timestamp, and metadata
- message-thread - Contains id, title, messages (list), created-at, and metadata

### Message Thread Operations:

- add-message, thread-length, get-message, last-message

### Mapping & Filtering:

- map-thread - Apply a function to each message, creating a new filtered thread
- filter-thread - Filter messages by predicate
- filter-by-role, filter-user-messages, filter-assistant-messages - Convenience filters
- transform-content - Transform message content strings

### Serialization (Thread → Text Log):

- serialize-thread - Output to stream or return string
- serialize-thread-to-file - Write to file

### Deserialization (Text Log → Thread):

- deserialize-thread - Parse from string or stream
- deserialize-thread-from-file - Read from file

### Convenience Functions:

- create-thread, create-chat-thread - Thread creation helpers
- thread-to-openai-format, openai-format-to-thread - API format conversion
- copy-thread - Deep copy a thread