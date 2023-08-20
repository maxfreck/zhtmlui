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
      BEGIN OF t_log_line,
        stamp TYPE timestampl,
        level TYPE int1,
        line  TYPE string,
      END OF t_log_line,
      t_log_table TYPE STANDARD TABLE OF t_log_line WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        VALUE(parent) TYPE REF TO cl_gui_container
        template      TYPE string
      EXCEPTIONS
        cntl_error
        cntl_install_error
        dp_install_error
        dp_error.

    METHODS construct.

    METHODS show.

    METHODS frontent_log_show.
    METHODS frontend_log_hide.

    EVENTS on_pai_call EXPORTING VALUE(ucomm) TYPE syst_ucomm.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF t_keyvalue,
        key   TYPE text80,
        value TYPE string,
      END OF t_keyvalue,
      t_keyvalue_table TYPE SORTED TABLE OF t_keyvalue WITH UNIQUE KEY key,

      t_translation    TYPE                 t_keyvalue,
      t_translation_t  TYPE                 t_keyvalue_table,

      t_query          TYPE                 t_keyvalue,
      t_query_t        TYPE                 t_keyvalue_table.

    DATA:
      i_template TYPE string,
      i_log      TYPE t_log_table,
      i_url      TYPE text80.

    METHODS preload_mime.
    METHODS preload_data IMPORTING id TYPE text80 url TYPE text80.
    METHODS get_translations RETURNING VALUE(ret) TYPE t_translation_t.
    METHODS translations_to_json IMPORTING translations TYPE t_translation_t RETURNING VALUE(ret) TYPE string.

    METHODS handle_sapevent IMPORTING action TYPE string query TYPE t_query_t.
    METHODS show_message IMPORTING type TYPE string text TYPE string display_like TYPE string.

    METHODS dispatch_api_request IMPORTING command TYPE string id TYPE i params TYPE t_query_t.
    METHODS api_reply IMPORTING id TYPE i reply TYPE string.

    METHODS map_string IMPORTING name TYPE string str TYPE string mime TYPE string DEFAULT 'text/plain'.

    METHODS run_frontend IMPORTING script TYPE string.

    METHODS load_binary_data IMPORTING like TYPE string.

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

  PRIVATE SECTION.
    METHODS on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action frame getdata postdata sender query_table.

    METHODS glue_query IMPORTING query TYPE cnht_query_table RETURNING VALUE(ret) TYPE t_query_t.
ENDCLASS.


CLASS zcl_html_ui IMPLEMENTATION.
  METHOD constructor.
    CALL METHOD super->constructor
      EXPORTING
        parent             = parent
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

    i_template = template.
  ENDMETHOD.

  METHOD construct.
    SET HANDLER on_sapevent FOR me.

    DATA lt_events TYPE cntl_simple_events.
    APPEND VALUE #( eventid = m_id_sapevent appl_event = abap_true ) TO lt_events.
    set_registered_events( events = lt_events ).

    preload_mime( ).

    load_mime_object(
      EXPORTING
        object_id = CONV text80( i_template )
        object_url = 'index.html'
      IMPORTING
        assigned_url = i_url
    ).
  ENDMETHOD.

  METHOD preload_mime.
    preload_data( id = 'ZSAPGUILOGGER' url = 'sapguilogger.js' ).
    preload_data( id = 'ZSAPGUI' url = 'sapgui.js' ).

    map_string(
      name = 'translations.json'
      str = translations_to_json( get_translations( ) )
      mime = 'application/json'
    ).
  ENDMETHOD.

  METHOD preload_data.
    DATA l_dummy_url TYPE text80.

    CALL METHOD load_mime_object
      EXPORTING
        object_id            = id
        object_url           = url
      IMPORTING
        assigned_url         = l_dummy_url
      EXCEPTIONS
        object_not_found     = 1
        dp_invalid_parameter = 2
        dp_error_general     = 3
        OTHERS               = 4.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |{ id } load failed with { sy-subrc }|.
    ENDIF.
  ENDMETHOD.

  METHOD get_translations.
    DATA l_texts TYPE STANDARD TABLE OF textpool.

    READ TEXTPOOL sy-cprog INTO l_texts LANGUAGE sy-langu.

    LOOP AT l_texts ASSIGNING FIELD-SYMBOL(<text>) WHERE id = 'I'.
      INSERT VALUE #( key = <text>-key value = <text>-entry ) INTO TABLE ret.
    ENDLOOP.
  ENDMETHOD.

  METHOD translations_to_json.
    IF translations IS INITIAL.
      ret = '{}'.
      RETURN.
    ENDIF.

    LOOP AT translations ASSIGNING FIELD-SYMBOL(<translation>).
      ret = |{ ret }"{ <translation>-key }": "{ <translation>-value }",\n|.
    ENDLOOP.

    DATA(len) = strlen( ret ) - 2.
    ret = |\{\n{ ret(len) }\n\}|.
  ENDMETHOD.

  METHOD show.
    show_url( EXPORTING url = i_url ).
  ENDMETHOD.

  METHOD frontent_log_show.
    run_frontend( 'console.show();' ).
  ENDMETHOD.

  METHOD frontend_log_hide.
    run_frontend( 'console.hide();' ).
  ENDMETHOD.

  METHOD on_sapevent.
    IF lines( query_table ) = 0.
      handle_sapevent( action = CONV #( action ) query = VALUE #( ( key = 'getdata' value = getdata ) ) ).
    ELSE.
      handle_sapevent( action = CONV #( action ) query = glue_query( query_table ) ).
    ENDIF.
  ENDMETHOD.

  METHOD glue_query.
    LOOP AT query ASSIGNING FIELD-SYMBOL(<query>).
      SPLIT <query>-name AT '_%%' INTO TABLE DATA(q).
      IF line_exists( ret[ key = q[ 1 ] ] ).
        ret[ key = q[ 1 ] ]-value = |{ ret[ key = q[ 1 ] ]-value }{ <query>-value }|.
      ELSE.
        INSERT VALUE #( key = q[ 1 ] value = <query>-value ) INTO TABLE ret.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD handle_sapevent.
    DATA getdata TYPE string VALUE ''.
    IF line_exists( query[ key = 'getdata' ] ).
      getdata = query[ key = 'getdata' ]-value.
    ENDIF.

    CASE action.
      WHEN 'message'.
        DATA l_disp TYPE string VALUE ''.
        IF NOT line_exists( query[ key = 'type' ] ) OR NOT line_exists( query[ key = 'text' ] ).
          RETURN.
        ENDIF.
        IF line_exists( query[ key = 'display-like' ] ).
          l_disp = query[ key = 'display-like' ]-value.
        ENDIF.
        show_message(
          text = CONV #( query[ key = 'text' ]-value )
          type = CONV #( query[ key = 'type' ]-value )
          display_like = l_disp
        ).
      WHEN 'api-request'.
        IF NOT line_exists( query[ key = 'command' ] ) OR NOT line_exists( query[ key = 'id' ] ).
          RETURN.
        ENDIF.
        dispatch_api_request(
          command = CONV #( query[ key = 'command' ]-value )
          id = CONV #( query[ key = 'id' ]-value )
          params = query
        ).
      WHEN 'pai'.
        TRANSLATE getdata TO UPPER CASE.
        RAISE EVENT on_pai_call EXPORTING ucomm = CONV #( getdata ).
      WHEN 'exception'.
        RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = getdata.
        RETURN.
      WHEN 'log'. "this is not implemented yet
        IF NOT line_exists( query[ key = 'level' ] ) OR NOT line_exists( query[ key = 'text' ] ).
          RETURN.
        ENDIF.
        log_write( str = query[ key = 'text' ]-value level = CONV #( query[ key = 'level' ]-value ) ).
        RETURN.
      WHEN 'url'.
        CALL FUNCTION 'CALL_BROWSER' EXPORTING url = CONV text255( getdata ).
      WHEN OTHERS.
        log_warning( |unhandled action: { action }: { getdata }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD show_message.
    IF display_like IS INITIAL.
      MESSAGE text TYPE type.
    ELSE.
      MESSAGE text TYPE type DISPLAY LIKE display_like.
    ENDIF.
  ENDMETHOD.

  METHOD dispatch_api_request.
    IF command = 'ping'.
      IF line_exists( params[ key = 'pong' ] ).
        api_reply( id = id reply = |pong { params[ key = 'pong' ]-value }| ).
        RETURN.
      ENDIF.
      api_reply( id = id reply = 'pong' ).
    ENDIF.
  ENDMETHOD.

  METHOD api_reply.
    DATA(l_reply) = reply.
    REPLACE ALL OCCURRENCES OF |'| IN l_reply WITH |\\'|.
    run_frontend( |sapgui.apiReceive({ id }, '{ l_reply }');| ).
  ENDMETHOD.

  METHOD map_string.
    DATA:
      lt_solix TYPE solix_tab,
      l_size   TYPE so_obj_len,
      l_url    TYPE text1024.

    SPLIT mime AT '/' INTO TABLE DATA(mime_tab).
    IF lines( mime_tab ) <> 2.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = 'Invalid mime is specified'.
    ENDIF.

    TRY.
        cl_bcs_convert=>string_to_solix(
          EXPORTING
            iv_string = str
          IMPORTING
            et_solix = lt_solix
            ev_size = l_size
        ).
      CATCH cx_bcs INTO DATA(x).
        RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = x->get_text( ) previous = x.
    ENDTRY.

    CALL METHOD load_data
      EXPORTING
        url                    = CONV text80( name )
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

  METHOD run_frontend.
    set_script( cl_bcs_convert=>string_to_soli( script ) ).
    execute_script( EXCEPTIONS dp_error = 1 cntl_error = 2 ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_html_ui EXPORTING text = |Failed to run frontend script with exit code { sy-subrc }|.
    ENDIF.
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
       AND objid LIKE like
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

  METHOD log_write.
    DATA l_timestamp TYPE timestampl.
    GET TIME FIELD l_timestamp.
    APPEND VALUE #( stamp = l_timestamp level = level line = str ) TO i_log.
  ENDMETHOD.

  METHOD log_notice.
    log_write( str = str level = cs_loglevel-notice ).
  ENDMETHOD.

  METHOD log_warning.
    log_write( str = str level = cs_loglevel-warning ).
  ENDMETHOD.

  METHOD log_error.
    log_write( str = str level = cs_loglevel-error ).
  ENDMETHOD.

  METHOD log_critical.
    log_write( str = str level = cs_loglevel-critical ).
  ENDMETHOD.

  METHOD log_alert.
    log_write( str = str level = cs_loglevel-alert ).
  ENDMETHOD.

  METHOD log_emergency.
    log_write( str = str level = cs_loglevel-emergency ).
  ENDMETHOD.

ENDCLASS.
