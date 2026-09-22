(defsystem "ecs-tutorial"
  :version "0.0.1"
  :author "Ysgard"
  :license "MIT"
  :depends-on (#:alexandria
               
               #:cl-liballegro
               #:cl-liballegro-nuklear
               
               #:livesupport)
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "main"))))
  :description "cl-fast-ecs framework tutorial"
  :defsystem-depends-on (#:deploy)
  :build-operation "deploy-op"
  :build-pathname #P"ecs-tutorial"
  :entry-point "ecs-tutorial:main")
