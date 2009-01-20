
USING: accessors calendar git-remote-tool git-misc kernel
locals sequences ui ui.gadgets ui.gadgets.buttons
ui.gadgets.packs ui.gadgets.labels ;

IN: git-remote-shelf

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: <git-remote-shelf> < track

  repository
  
  remote
  remote-branch

  fetch-period

  closed
  last-refresh ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-git-remote-shelf ( GADGET -- )

  [let | REPO [ GADGET repository>> ] |

    GADGET clear-gadget

    GADGET sizes>> delete-all

    GADGET

    ! Remote button

    GADGET remote>>
    [
      drop

      <pile>

      REPO list-remotes

      [| REMOTE |

        REMOTE
        [
          drop
          GADGET REMOTE >>remote drop
          GADGET "master" >>remote-branch drop
          GADGET refresh-git-remote-shelf
        ]
        <bevel-button> add-gadget

      ]
      each

      "Select a remote" open-window
      
    ]
    <bevel-button> 1/5 track-add

    ! Remote branch button

    GADGET remote-branch>>
    [
      drop

      <pile>

      REPO GADGET remote>> list-remote-branches

      [| REMOTE-BRANCH |

        REMOTE-BRANCH
        [
          drop
          GADGET REMOTE-BRANCH >>remote-branch drop
          GADGET refresh-git-remote-shelf
        ]
        <bevel-button> add-gadget
      ]
      
      each

      "Select a remote branch" open-window

    ]
    <bevel-button> 1/5 track-add

    ! Fetch button

    "Fetch"
    [
      drop
      [let | REMOTE [ GADGET remote>> ] |
        REPO { "git" "fetch" REMOTE } git-process popup-if-error ]
      
      GADGET refresh-git-remote-shelf
    ]
    <bevel-button> 1/5 track-add

    ! Available changes

    [let | REMOTE        [ GADGET remote>>        ]
           REMOTE-BRANCH [ GADGET remote-branch>> ] |

      [let | ARG [ { ".." REMOTE "/" REMOTE-BRANCH } concat ] |

        [let | PROCESS [ REPO { "git" "log" ARG } git-process ] |

          PROCESS stdout>>
            [

              "Mergable"
              [ drop PROCESS popup-process-window ]
              <bevel-button> 1/5 track-add

              "Merge"
              [
                drop

                [let | ARG [ { REMOTE "/" REMOTE-BRANCH } concat ] |

                  REPO { "git" "merge" ARG } git-process popup-process-window

                ]

                GADGET refresh-git-remote-shelf

              ]
              <bevel-button> 1/5 track-add

            ]
            [
              "" <label> 1/5 track-add
              "" <label> 1/5 track-add
            ]
          if

        ] ] ]

    ! Pushable changes

    [let | REMOTE        [ GADGET remote>>        ]
           REMOTE-BRANCH [ GADGET remote-branch>> ] |

      [let | ARG [ { REMOTE "/" REMOTE-BRANCH ".." } concat ] |

        [let | PROCESS [ REPO { "git" "log" ARG } git-process ] |

          PROCESS stdout>>
            [
                "Pushable"
                [ drop PROCESS popup-process-window ]
                <bevel-button> 1/5 track-add

                "Push"
                [
                  drop

                  REPO { "git" "push" REMOTE REMOTE-BRANCH }
                  git-process
                  popup-process-window

                  GADGET refresh-git-remote-shelf

                ]
                <bevel-button> 1/5 track-add

            ]
            [
              "" <label> 1/5 track-add
              "" <label> 1/5 track-add
            ]
          if
          
        ] ] ]

    drop ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-remote-shelf ( REPO -- gadget )

  <git-remote-shelf> new init-track

  { 1 0 } >>orientation

  REPO >>repository

  "origin" >>remote

  "master" >>remote-branch

  5 minutes >>fetch-period

  dup refresh-git-remote-shelf ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

