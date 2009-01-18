
USING: accessors arrays assocs classes.tuple kernel locals
locals.parser locals.types namespaces parser quotations
sequences slots unicode.case vectors ;

IN: with-slots

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: make-reader-binding ( SLOT-NAME OBJECT-WORD -- binding )

  SLOT-NAME >upper

  OBJECT-WORD  SLOT-NAME reader-word  2array  >quotation

  tuck make-local-word swap 2array ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: make-writer-binding ( SLOT-NAME OBJECT-WORD -- binding )

  SLOT-NAME >upper "!" append

  OBJECT-WORD  SLOT-NAME writer-word  2array  >quotation

  tuck make-local-word swap 2array ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: bindings->vars ( bindings -- vars ) keys [ dup name>> swap 2array ] map ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: [with-slots ( ACCUM -- accum )

  [let | CLASS  [ scan-word        ]
         OBJECT [ "OBJECT" <local> ] |

    [let | LET-VARS [ { { "OBJECT" OBJECT } }        ]
           SLOTS    [ CLASS all-slots [ name>> ] map ] |

      [

        in-lambda? on
        LET-VARS locals set
        LET-VARS push-locals

        ! process wlet

        [let | READER-BINDINGS [ SLOTS [ OBJECT make-reader-binding ] map ]
               WRITER-BINDINGS [ SLOTS [ OBJECT make-writer-binding ] map ] |

          [let | WLET-BINDINGS [ READER-BINDINGS WRITER-BINDINGS append ] |

            [let | WLET-VARS [ WLET-BINDINGS bindings->vars ] |

              [let | WLET-BODY [ WLET-VARS \ ] (parse-lambda) ] |
              
                [let | WLET [ WLET-BINDINGS WLET-BODY <wlet> ] |

                  100 <vector> WLET parsed-lambda >quotation ] ] ] ] ]

        ! end process wlet

        LET-VARS pop-locals

      ]

      with-scope

      [let | LET-BINDINGS [ { { OBJECT [ ] } } ]
             LET-BODY     [ ]                    |

        [let | LET [ LET-BINDINGS LET-BODY <let> ] |

          ACCUM LET parsed-lambda ] ] ] ] ; parsing

