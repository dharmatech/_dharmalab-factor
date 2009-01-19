
USING: accessors git-tool io.directories io.pathnames kernel
locals namespaces sequences ui ui.gadgets ui.gadgets.buttons
ui.gadgets.editors ui.gadgets.labels ui.gadgets.packs
ui.gadgets.tracks ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

IN: git-status-tool

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: <git-status-gadget> < pack

  repository

  to-commit-new
  to-commit-modified
  to-commit-deleted
  modified
  deleted
  untracked

  closed ;
  
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-status ( GADGET -- )

 [let | LINES [ GADGET repository>> { "git" "status" } git-process stdout>> ] |

    GADGET
    
      LINES "# Changes to be committed:" git-status-section
        [ "new file:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>to-commit-new
    
      LINES "# Changes to be committed:" git-status-section
        [ "modified:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>to-commit-modified

      LINES "# Changes to be committed:" git-status-section
        [ "deleted:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>to-commit-deleted

      LINES "# Changed but not updated:" git-status-section
        [ "modified:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>modified
    
      LINES "# Changed but not updated:" git-status-section
        [ "deleted:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>deleted

      LINES "# Untracked files:" git-status-section >>untracked ]

  drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-git-status-gadget ( GADGET -- )

  GADGET refresh-status

  GADGET clear-gadget

  GADGET

  ! Repository label

  "Repository: "
  GADGET repository>> [ current-directory get ] with-directory append
  <label>
  add-gadget

  ! Commit section

  [wlet | add-commit-path-button [| TEXT PATH |

            { 1 0 } <track>

              TEXT <label> 2/8 track-add
              PATH <label> 6/8 track-add

              "Reset"
              [
                drop
                
                GADGET repository>>
                { "git" "reset" "HEAD" PATH }
                git-process
                drop
                
                GADGET refresh-git-status-gadget
              ]
              <bevel-button> f track-add

            add-gadget ] |

    GADGET to-commit
    [
      "Changes to be committed" <label> reverse-video-theme add-gadget

      GADGET to-commit-new>>
      [| PATH | "new file: " PATH add-commit-path-button ]
      each

      GADGET to-commit-modified>>
      [| PATH | "modified: " PATH add-commit-path-button ]
      each

      GADGET to-commit-deleted>>
      [| PATH | "deleted: " PATH add-commit-path-button ]
      each

      <pile> 1 >>fill

        [let | EDITOR [ <editor> "COMMIT MESSAGE" over set-editor-string ] |

          EDITOR add-gadget
  
          "Commit"
          [
           drop
           [let | MSG [ EDITOR editor-string ] |

              GADGET repository>>
              { "git" "commit" "-m" MSG } git-process
              popup-if-error ]
           GADGET refresh-git-status-gadget
          ]
          <bevel-button>
          add-gadget ]
       
      add-gadget

    ]
    when ]

  ! Modified section

  GADGET modified>>
  [
    "Modified but not updated" <label> reverse-video-theme add-gadget

    GADGET modified>>
    [| PATH |

      <shelf>

        PATH <label> add-gadget

        "Add"
        [
          drop
          GADGET repository>> { "git" "add" PATH } git-process popup-if-error
          GADGET refresh-git-status-gadget
        ]
        <bevel-button> add-gadget

        "Diff"
        [
          drop
          GADGET repository>> { "git" "diff" PATH } git-process
          popup-process-window
        ]
        <bevel-button> add-gadget

      add-gadget
      
    ]
    each
    
  ]
  when

  ! Untracked section

  GADGET untracked>>
  [
    "Untracked files" <label> reverse-video-theme add-gadget

    GADGET untracked>>
    [| PATH |

      { 1 0 } <track>

        PATH <label> f track-add

        "Add"
        [
          drop
          GADGET repository>> { "git" "add" PATH } git-process popup-if-error
          GADGET refresh-git-status-gadget
        ]
        <bevel-button> f track-add

      add-gadget

    ]
    each
    
  ]
  when

  ! Refresh button

  "Refresh" [ drop GADGET refresh-git-status-gadget ] <bevel-button> add-gadget

  drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-status-tool ( REPO -- )

  <git-status-gadget> new-gadget

    { 0 1 } >>orientation

    1       >>fill

    REPO >>repository

  dup refresh-git-status-gadget

  "git-status-tool" open-window ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

