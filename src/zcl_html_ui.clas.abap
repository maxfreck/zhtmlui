CLASS zcl_html_ui DEFINITION PUBLIC CREATE PUBLIC INHERITING FROM cl_gui_html_viewer.
  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_loglevel,
        notice    TYPE int1 VALUE 1,
        warning   TYPE int1 VALUE 2,
        error     TYPE int1 VALUE 3,
        critical  TYPE int1 VALUE 4,
        alert     TYPE int1 VALUE 5,
        emergency TYPE int1 VALUE 6,
      END OF cs_loglevel.

    TYPES:
      BEGIN OF mty_s_log_line,
        stamp TYPE timestampl,
        level TYPE int1,
        line  TYPE string,
      END OF mty_s_log_line,
      mty_t_log_table TYPE STANDARD TABLE OF mty_s_log_line WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        VALUE(io_parent) TYPE REF TO cl_gui_container
        iv_app           TYPE string
      EXCEPTIONS
        cntl_error
        cntl_install_error
        dp_install_error
        dp_error.

    METHODS construct.

    METHODS show.

    EVENTS on_pai_call EXPORTING VALUE(ev_ucomm) TYPE syst_ucomm.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF mty_s_keyvalue,
        key   TYPE text80,
        value TYPE string,
      END OF mty_s_keyvalue,
      mty_t_keyvalue_table TYPE SORTED TABLE OF mty_s_keyvalue WITH UNIQUE KEY key,

      mty_s_translation    TYPE                 mty_s_keyvalue,
      mty_t_translation_t  TYPE                 mty_t_keyvalue_table,

      mty_s_query          TYPE                 mty_s_keyvalue,
      mty_t_query_t        TYPE                 mty_t_keyvalue_table.

    CONSTANTS:
      mc_mime_url  TYPE string VALUE '/SAP/PUBLIC/ZHTMLUI/',
      mc_start_url TYPE text80 VALUE 'index.html'.

    DATA:
      mv_system_dir TYPE string,
      mo_mime_api   TYPE REF TO if_mr_api,
      mv_app        TYPE string,
      mo_log        TYPE mty_t_log_table.

    METHODS open_devtools.
    METHODS preload_mime.
    METHODS preload_repo
      IMPORTING
        iv_repo TYPE string.

    METHODS get_translations
      RETURNING
        VALUE(rv_ret) TYPE mty_t_translation_t.

    METHODS translations_to_json
      IMPORTING
        it_translations TYPE mty_t_translation_t
      RETURNING
        VALUE(rv_ret)   TYPE string.

    METHODS handle_sapevent
      IMPORTING
        iv_action TYPE string
        it_query  TYPE mty_t_query_t.

    METHODS show_message
      IMPORTING
        iv_type         TYPE string
        iv_text         TYPE string
        iv_display_like TYPE string.

    METHODS dispatch_api_request
      IMPORTING
        iv_command TYPE string
        iv_id      TYPE i
        it_params  TYPE mty_t_query_t.

    METHODS api_reply
      IMPORTING
        iv_id    TYPE i
        iv_reply TYPE string.

    METHODS map_string
      IMPORTING
        iv_name TYPE string
        iv_str  TYPE string
        iv_mime TYPE string DEFAULT 'text/plain'.

    METHODS run_frontend
      IMPORTING
        iv_script TYPE string.

    METHODS load_binary_data
      IMPORTING
        iv_like TYPE string.

    METHODS get_mime_object
      IMPORTING
        iv_url      TYPE csequence
      EXPORTING
        et_mime_tab TYPE solix_tab
        ev_size     TYPE i.

    " It's a dummy logging system.
    " To clean the code, we must extract logging into a separate class.
    METHODS:
      log_write IMPORTING str TYPE string level TYPE int1 DEFAULT 0,
      log_notice    IMPORTING str TYPE string,
      log_warning   IMPORTING str TYPE string,
      log_error     IMPORTING str TYPE string,
      log_critical  IMPORTING str TYPE string,
      log_alert     IMPORTING str TYPE string,
      log_emergency IMPORTING str TYPE string.

    METHODS is_gui_for_windows
      RETURNING
        VALUE(rv_ret) TYPE abap_bool.

  PRIVATE SECTION.
    METHODS on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING
        action
        frame
        getdata
        postdata
        sender
        query_table.

    METHODS glue_query
      IMPORTING
        it_query      TYPE cnht_query_table
      RETURNING
        VALUE(rv_ret) TYPE mty_t_query_t.

ENDCLASS.



CLASS zcl_html_ui IMPLEMENTATION.


  METHOD api_reply.
    DATA(l_reply) = iv_reply.
    REPLACE ALL OCCURRENCES OF |'| IN l_reply WITH |\\'|.
    run_frontend( |sapgui.apiReceive({ iv_id }, '{ l_reply }');| ).
  ENDMETHOD.


  METHOD construct.
    mo_mime_api = cl_mime_repository_api=>get_api( ).

    SET HANDLER on_sapevent FOR me.


    DATA lt_events TYPE cntl_simple_events.
    APPEND VALUE #( eventid = m_id_sapevent appl_event = abap_true ) TO lt_events.
    set_registered_events( events = lt_events ).

    preload_mime( ).
  ENDMETHOD.


  METHOD constructor.
    CALL METHOD super->constructor
      EXPORTING
        parent             = io_parent
        uiflag             = ( uiflag_noiemenu + uiflag_no3dborder )
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4.
    CASE sy-subrc.
      WHEN 1.
        RAISE cntl_error.
      WHEN 2.
        RAISE cntl_install_error.
      WHEN 3.
        RAISE dp_install_error.
      WHEN 4.
        RAISE dp_error.
    ENDCASE.

    mv_app = iv_app.
    cl_gui_frontend_services=>get_system_directory(
    CHANGING
      system_directory     = mv_system_dir
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4 ).
  ENDMETHOD.


  METHOD dispatch_api_request.
    IF iv_command = 'ping'.
      IF line_exists( it_params[ key = 'pong' ] ).
        api_reply( iv_id = iv_id iv_reply = |pong { it_params[ key = 'pong' ]-value }| ).
        RETURN.
      ENDIF.
      api_reply( iv_id = iv_id iv_reply = 'pong' ).
    ENDIF.
  ENDMETHOD.


  METHOD get_mime_object.
    mo_mime_api->get(
      EXPORTING
        i_url = iv_url
      IMPORTING
        e_content = DATA(lv_mime)
      EXCEPTIONS
        OTHERS = 99 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    et_mime_tab = cl_bcs_convert=>xstring_to_solix( lv_mime ).
    ev_size = xstrlen( lv_mime ).
  ENDMETHOD.


  METHOD get_translations.
    DATA l_texts TYPE STANDARD TABLE OF textpool.

    READ TEXTPOOL sy-cprog INTO l_texts LANGUAGE sy-langu.

    LOOP AT l_texts ASSIGNING FIELD-SYMBOL(<text>) WHERE id = 'I'.
      INSERT VALUE #( key = <text>-key value = <text>-entry ) INTO TABLE rv_ret.
    ENDLOOP.
  ENDMETHOD.


  METHOD glue_query.
    LOOP AT it_query ASSIGNING FIELD-SYMBOL(<query>).
      SPLIT <query>-name AT '_%%' INTO TABLE DATA(q).
      IF line_exists( rv_ret[ key = q[ 1 ] ] ).
        rv_ret[ key = q[ 1 ] ]-value = |{ rv_ret[ key = q[ 1 ] ]-value }{ <query>-value }|.
      ELSE.
        INSERT VALUE #( key = q[ 1 ] value = <query>-value ) INTO TABLE rv_ret.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD handle_sapevent.
    DATA getdata TYPE string VALUE ''.
    IF line_exists( it_query[ key = 'getdata' ] ).
      getdata = it_query[ key = 'getdata' ]-value.
    ENDIF.

    CASE iv_action.
      WHEN 'message'.
        DATA l_disp TYPE string VALUE ''.
        IF NOT line_exists( it_query[ key = 'type' ] ) OR NOT line_exists( it_query[ key = 'text' ] ).
          RETURN.
        ENDIF.
        IF line_exists( it_query[ key = 'display-like' ] ).
          l_disp = it_query[ key = 'display-like' ]-value.
        ENDIF.
        show_message(
          iv_text = CONV #( it_query[ key = 'text' ]-value )
          iv_type = CONV #( it_query[ key = 'type' ]-value )
          iv_display_like = l_disp
        ).
      WHEN 'api-request'.
        IF NOT line_exists( it_query[ key = 'command' ] ) OR NOT line_exists( it_query[ key = 'id' ] ).
          RETURN.
        ENDIF.
        dispatch_api_request(
          iv_command = CONV #( it_query[ key = 'command' ]-value )
          iv_id = CONV #( it_query[ key = 'id' ]-value )
          it_params = it_query
        ).
      WHEN 'pai'.
        TRANSLATE getdata TO UPPER CASE.
        RAISE EVENT on_pai_call EXPORTING ev_ucomm = CONV #( getdata ).
      WHEN 'exception'.
        RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = getdata.
        RETURN.
      WHEN 'log'. "this is not implemented yet
        IF NOT line_exists( it_query[ key = 'level' ] ) OR NOT line_exists( it_query[ key = 'text' ] ).
          RETURN.
        ENDIF.
        log_write( str = it_query[ key = 'text' ]-value level = CONV #( it_query[ key = 'level' ]-value ) ).
        RETURN.
      WHEN 'url'.
        CALL FUNCTION 'CALL_BROWSER' EXPORTING url = CONV text255( getdata ).
      WHEN OTHERS.
        log_warning( |unhandled action: { iv_action }: { getdata }| ).
    ENDCASE.
  ENDMETHOD.


  METHOD is_gui_for_windows.
    CALL FUNCTION 'GUI_HAS_ACTIVEX'
      IMPORTING
        return = rv_ret.
  ENDMETHOD.


  METHOD load_binary_data.
    TYPES:
      BEGIN OF t_lib_entry,
        objid TYPE w3objid,
        value TYPE w3_qvalue,
      END OF t_lib_entry.

    DATA:
      l_dummy_url TYPE                   text80,
      lt_files    TYPE STANDARD TABLE OF t_lib_entry.

    SELECT objid value FROM wwwparams INTO TABLE lt_files
     WHERE relid = 'MI'
       AND objid LIKE iv_like
       AND name = 'filename'.

    LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<file>).
      CALL METHOD load_mime_object
        EXPORTING
          object_id            = <file>-objid
          object_url           = <file>-value
        IMPORTING
          assigned_url         = l_dummy_url
        EXCEPTIONS
          object_not_found     = 1
          dp_invalid_parameter = 2
          dp_error_general     = 3
          OTHERS               = 4.

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |{ <file>-value } load failed with { sy-subrc }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD log_alert.
    log_write( str = str level = cs_loglevel-alert ).
  ENDMETHOD.


  METHOD log_critical.
    log_write( str = str level = cs_loglevel-critical ).
  ENDMETHOD.


  METHOD log_emergency.
    log_write( str = str level = cs_loglevel-emergency ).
  ENDMETHOD.


  METHOD log_error.
    log_write( str = str level = cs_loglevel-error ).
  ENDMETHOD.


  METHOD log_notice.
    log_write( str = str level = cs_loglevel-notice ).
  ENDMETHOD.


  METHOD log_warning.
    log_write( str = str level = cs_loglevel-warning ).
  ENDMETHOD.


  METHOD log_write.
    DATA l_timestamp TYPE timestampl.
    GET TIME FIELD l_timestamp.
    APPEND VALUE #( stamp = l_timestamp level = level line = str ) TO mo_log.
  ENDMETHOD.


  METHOD map_string.
    DATA:
      lt_solix TYPE solix_tab,
      l_size   TYPE so_obj_len,
      l_url    TYPE text1024.

    SPLIT iv_mime AT '/' INTO TABLE DATA(mime_tab).
    IF lines( mime_tab ) <> 2.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = 'Invalid mime is specified'.
    ENDIF.

    TRY.
        cl_bcs_convert=>string_to_solix(
          EXPORTING
            iv_string = iv_str
          IMPORTING
            et_solix = lt_solix
            ev_size = l_size
        ).
      CATCH cx_bcs INTO DATA(x).
        RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = x->get_text( ) previous = x.
    ENDTRY.

    CALL METHOD load_data
      EXPORTING
        url                    = CONV text80( iv_name )
        type                   = CONV text80( mime_tab[ 1 ] )
        subtype                = CONV text80( mime_tab[ 2 ] )
        size                   = CONV #( l_size )
      IMPORTING
        assigned_url           = l_url
      CHANGING
        data_table             = lt_solix
      EXCEPTIONS
        dp_invalid_parameter   = 1
        dp_error_general       = 2
        cntl_error             = 3
        html_syntax_notcorrect = 4
        OTHERS                 = 2.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |load_data failed with { sy-subrc }|.
    ENDIF.
  ENDMETHOD.


  METHOD on_sapevent.
    IF lines( query_table ) = 0.
      handle_sapevent( iv_action = CONV #( action ) it_query = VALUE #( ( key = 'getdata' value = getdata ) ) ).
    ELSE.
      handle_sapevent( iv_action = CONV #( action ) it_query = glue_query( query_table ) ).
    ENDIF.
  ENDMETHOD.


  METHOD open_devtools.
    IF is_gui_for_windows( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |IE DevTools not supported on frontend OS|.
    ENDIF.

    DATA lv_system_directory TYPE string.

    DATA(lv_dev_tools) = mv_system_dir && `\F12\IEChooser.exe`.

    cl_gui_frontend_services=>execute(
      EXPORTING
        application            = lv_dev_tools
      EXCEPTIONS
        cntl_error             = 1
        error_no_gui           = 2
        bad_parameter          = 3
        file_not_found         = 4
        path_not_found         = 5
        file_extension_unknown = 6
        error_execute_failed   = 7
        synchronous_failed     = 8
        not_supported_by_gui   = 9
        OTHERS                 = 10 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD preload_mime.
    map_string( iv_name = 'translations.json'
                iv_str = translations_to_json( get_translations( ) )
                iv_mime = 'application/json' ).

    preload_repo( mc_mime_url ).
    preload_repo( mv_app ).
  ENDMETHOD.


  METHOD preload_repo.
    mo_mime_api->file_list(
      EXPORTING
        i_recursive_call = abap_true
        i_url = iv_repo
      IMPORTING
        e_files = DATA(lt_file_list) ).

    LOOP AT lt_file_list ASSIGNING FIELD-SYMBOL(<lv_file>).
      get_mime_object(
        EXPORTING
          iv_url = <lv_file>
        IMPORTING
          et_mime_tab = DATA(lt_mime)
          ev_size = DATA(lv_size)  ).

      DATA(lv_url) = CONV text80( replace( val = <lv_file> sub = iv_repo with = '' ) ).

      load_data(
        EXPORTING
          url = lv_url
          size = lv_size
        CHANGING
          data_table   = lt_mime
        EXCEPTIONS
          dp_invalid_parameter   = 1
          dp_error_general       = 2
          cntl_error             = 3
          html_syntax_notcorrect = 4
          OTHERS                 = 2 ).

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |load_data failed with { sy-subrc }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_frontend.
    set_script( cl_bcs_convert=>string_to_soli( iv_script ) ).
    execute_script( EXCEPTIONS dp_error = 1 cntl_error = 2 ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |Failed to run frontend script with exit code { sy-subrc }|.
    ENDIF.
  ENDMETHOD.


  METHOD show.
    show_url( EXPORTING url = mc_start_url ).
  ENDMETHOD.


  METHOD show_message.
    IF iv_display_like IS INITIAL.
      MESSAGE iv_text TYPE iv_type.
    ELSE.
      MESSAGE iv_text TYPE iv_type DISPLAY LIKE iv_display_like.
    ENDIF.
  ENDMETHOD.


  METHOD translations_to_json.
    IF it_translations IS INITIAL.
      rv_ret = '{}'.
      RETURN.
    ENDIF.

    LOOP AT it_translations ASSIGNING FIELD-SYMBOL(<translation>).
      rv_ret = |{ rv_ret }"{ <translation>-key }": "{ <translation>-value }",\n|.
    ENDLOOP.

    DATA(len) = strlen( rv_ret ) - 2.
    rv_ret = |\{\n{ rv_ret(len) }\n\}|.
  ENDMETHOD.
ENDCLASS.
