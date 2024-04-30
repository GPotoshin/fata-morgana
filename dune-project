(lang dune 3.12)

(name fata-morgana)

(generate_opam_files true)

(source
 (github GPotoshin/fata-morgana))

(authors "George Potoshin")

(maintainers "George Potosin")

(license LICENSE)

(documentation https://url/to/documentation)
(using ctypes 0.3)

(package
 (name fata-morgana)
 (synopsis "alternative to manim")
 (description "Script your vidoes with fata morgana")
 (depends ocaml dune ctypes))
; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
