(asdf:defsystem #:ai
  :description "Common Lisp implementation for the https://hybrid-ai.agency project"
  :author "Mark Watson"
  :license "AGPLv3"
  :serial t
  :components ((:file "project")
               (:file "mlog")
               (:file "ai")))
