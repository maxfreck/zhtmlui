class zcl_html_ui definition public create public inheriting from cl_gui_html_viewer.
  public section.

    constants:
      c_loglevel_notice    type int1 value 1,
      c_loglevel_warning   type int1 value 2,
      c_loglevel_error     type int1 value 3,
      c_loglevel_critical  type int1 value 4,
      c_loglevel_alert     type int1 value 5,
      c_loglevel_emergency type int1 value 6.

    types:
      begin of t_log_line,
        stamp type timestampl,
        level type int1,
        line  type string,
      end of t_log_line,
      t_log_table type standard table of t_log_line with empty key.

    methods constructor
      importing
        value(parent) type ref to cl_gui_container
        template      type string
      exceptions
        cntl_error
        cntl_install_error
        dp_install_error
        dp_error.

    methods construct.

    methods show.

    methods frontent_log_show.
    methods frontend_log_hide.

    events on_pai_call exporting value(ucomm) type syst_ucomm.

  protected section.
    types:
      begin of t_keyvalue,
        key   type text80,
        value type string,
      end of t_keyvalue,
      t_keyvalue_table type sorted table of t_keyvalue with unique key key,

      t_translation    type                 t_keyvalue,
      t_translation_t  type                 t_keyvalue_table,

      t_query          type                 t_keyvalue,
      t_query_t        type                 t_keyvalue_table.

    data:
      i_template type string,
      i_log      type t_log_table,
      i_url      type text80.

    methods preload_mime.
    methods preload_data importing id type text80 url type text80.
    methods get_translations returning value(ret) type t_translation_t.
    methods translations_to_json importing translations type t_translation_t returning value(ret) type string.

    methods handle_sapevent importing action type string query type t_query_t.
    methods show_message importing type type string text type string display_like type string.

    methods dispatch_api_request importing command type string id type i params type t_query_t.
    methods api_reply importing id type i reply type string.

    methods map_string importing name type string str type string mime type string default 'text/plain'.

    methods run_frontend importing script type string.

    methods load_binary_data importing like type string.

    " It's a dummy logging system.
    " To clean the code, we must extract logging into a separate class.
    methods:
      log_write importing str type string level type int1 default 0,
      log_notice    importing str type string,
      log_warning   importing str type string,
      log_error     importing str type string,
      log_critical  importing str type string,
      log_alert     importing str type string,
      log_emergency importing str type string.

  private section.
    methods on_sapevent for event sapevent of cl_gui_html_viewer
      importing action frame getdata postdata sender query_table.

    methods glue_query importing query type cnht_query_table returning value(ret) type t_query_t.
endclass.


class zcl_html_ui implementation.
  method constructor.
    call method super->constructor
      exporting
        parent             = parent
        uiflag             = ( uiflag_noiemenu + uiflag_no3dborder )
      exceptions
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4.
    case sy-subrc.
      when 1.
        raise cntl_error.
      when 2.
        raise cntl_install_error.
      when 3.
        raise dp_install_error.
      when 4.
        raise dp_error.
    endcase.

    i_template = template.
  endmethod.

  method construct.
    set handler on_sapevent for me.

    data lt_events type cntl_simple_events.
    append value #( eventid = m_id_sapevent appl_event = abap_true ) to lt_events.
    set_registered_events( events = lt_events ).

    preload_mime( ).

    load_mime_object(
      exporting
        object_id = conv text80( i_template )
        object_url = 'index.html'
      importing
        assigned_url = i_url
    ).
  endmethod.

  method preload_mime.
    preload_data( id = 'ZSAPGUILOGGER' url = 'sapguilogger.js' ).
    preload_data( id = 'ZSAPGUI' url = 'sapgui.js' ).

    map_string(
      name = 'translations.json'
      str = translations_to_json( get_translations( ) )
      mime = 'application/json'
    ).
  endmethod.

  method preload_data.
    data l_dummy_url type text80.

    call method load_mime_object
      exporting
        object_id            = id
        object_url           = url
      importing
        assigned_url         = l_dummy_url
      exceptions
        object_not_found     = 1
        dp_invalid_parameter = 2
        dp_error_general     = 3
        others               = 4.

    if sy-subrc <> 0.
      raise exception type zcx_html_ui exporting text = |{ id } load failed with { sy-subrc }|.
    endif.
  endmethod.

  method get_translations.
    data l_texts type standard table of textpool.

    read textpool sy-cprog into l_texts language sy-langu.

    loop at l_texts assigning field-symbol(<text>) where id = 'I'.
      insert value #( key = <text>-key value = <text>-entry ) into table ret.
    endloop.
  endmethod.

  method translations_to_json.
    if translations is initial.
      ret = '{}'.
      return.
    endif.

    loop at translations assigning field-symbol(<translation>).
      ret = |{ ret }"{ <translation>-key }": "{ <translation>-value }",\n|.
    endloop.

    data(len) = strlen( ret ) - 2.
    ret = |\{\n{ ret(len) }\n\}|.
  endmethod.

  method show.
    show_url( exporting url = i_url ).
  endmethod.

  method frontent_log_show.
    run_frontend( 'console.show();' ).
  endmethod.

  method frontend_log_hide.
    run_frontend( 'console.hide();' ).
  endmethod.

  method on_sapevent.
    if lines( query_table ) = 0.
      handle_sapevent( action = conv #( action ) query = value #( ( key = 'getdata' value = getdata ) ) ).
    else.
      handle_sapevent( action = conv #( action ) query = glue_query( query_table ) ).
    endif.
  endmethod.

  method glue_query.
    loop at query assigning field-symbol(<query>).
      split <query>-name at '_%%' into table data(q).
      if line_exists( ret[ key = q[ 1 ] ] ).
        ret[ key = q[ 1 ] ]-value = |{ ret[ key = q[ 1 ] ]-value }{ <query>-value }|.
      else.
        insert value #( key = q[ 1 ] value = <query>-value ) into table ret.
      endif.
    endloop.
  endmethod.

  method handle_sapevent.
    data getdata type string value ''.
    if line_exists( query[ key = 'getdata' ] ).
      getdata = query[ key = 'getdata' ]-value.
    endif.

    case action.
      when 'message'.
        data l_disp type string value ''.
        if not line_exists( query[ key = 'type' ] ) or not line_exists( query[ key = 'text' ] ).
          return.
        endif.
        if line_exists( query[ key = 'display-like' ] ).
          l_disp = query[ key = 'display-like' ]-value.
        endif.
        show_message(
          text = conv #( query[ key = 'text' ]-value )
          type = conv #( query[ key = 'type' ]-value )
          display_like = l_disp
        ).
      when 'api-request'.
        if not line_exists( query[ key = 'command' ] ) or not line_exists( query[ key = 'id' ] ).
          return.
        endif.
        dispatch_api_request(
          command = conv #( query[ key = 'command' ]-value )
          id = conv #( query[ key = 'id' ]-value )
          params = query
        ).
      when 'pai'.
        translate getdata to upper case.
        raise event on_pai_call exporting ucomm = conv #( getdata ).
      when 'exception'.
        raise exception type zcx_html_ui exporting text = getdata.
        return.
      when 'log'. "this is not implemented yet
        if not line_exists( query[ key = 'level' ] ) or not line_exists( query[ key = 'text' ] ).
          return.
        endif.
        log_write( str = query[ key = 'text' ]-value level = conv #( query[ key = 'level' ]-value ) ).
        return.
      when 'url'.
        call function 'CALL_BROWSER' exporting url = conv text255( getdata ).
      when others.
        log_warning( |unhandled action: { action }: { getdata }| ).
    endcase.
  endmethod.

  method show_message.
    if display_like is initial.
      message text type type.
    else.
      message text type type display like display_like.
    endif.
  endmethod.

  method dispatch_api_request.
    if command = 'ping'.
      if line_exists( params[ key = 'pong' ] ).
        api_reply( id = id reply = |pong { params[ key = 'pong' ]-value }| ).
        return.
      endif.
      api_reply( id = id reply = 'pong' ).
    endif.
  endmethod.

  method api_reply.
    data(l_reply) = reply.
    replace all occurrences of |'| in l_reply with |\\'|.
    run_frontend( |sapgui.apiReceive({ id }, '{ l_reply }');| ).
  endmethod.

  method map_string.
    data:
      lt_solix type solix_tab,
      l_size   type so_obj_len,
      l_url    type text1024.

    split mime at '/' into table data(mime_tab).
    if lines( mime_tab ) <> 2.
      raise exception type zcx_html_ui exporting text = 'Invalid mime is specified'.
    endif.

    try.
        cl_bcs_convert=>string_to_solix(
          exporting
            iv_string = str
          importing
            et_solix = lt_solix
            ev_size = l_size
        ).
      catch cx_bcs into data(x).
        raise exception type zcx_html_ui exporting text = x->get_text( ) previous = x.
    endtry.

    call method load_data
      exporting
        url                    = conv text80( name )
        type                   = conv text80( mime_tab[ 1 ] )
        subtype                = conv text80( mime_tab[ 2 ] )
        size                   = conv #( l_size )
      importing
        assigned_url           = l_url
      changing
        data_table             = lt_solix
      exceptions
        dp_invalid_parameter   = 1
        dp_error_general       = 2
        cntl_error             = 3
        html_syntax_notcorrect = 4
        others                 = 2.

    if sy-subrc <> 0.
      raise exception type zcx_html_ui exporting text = |load_data failed with { sy-subrc }|.
    endif.
  endmethod.

  method run_frontend.
    set_script( cl_bcs_convert=>string_to_soli( script ) ).
    execute_script( exceptions dp_error = 1 cntl_error = 2 ).

    if sy-subrc <> 0.
      raise exception type zcx_html_ui exporting text = |Failed to run frontend script with exit code { sy-subrc }|.
    endif.
  endmethod.

  method load_binary_data.
    types:
      begin of t_lib_entry,
        objid type w3objid,
        value type w3_qvalue,
      end of t_lib_entry.

    data:
      l_dummy_url type                   text80,
      lt_files    type standard table of t_lib_entry.

    select objid value from wwwparams into table lt_files
     where relid = 'MI'
       and objid like like
       and name = 'filename'.

    loop at lt_files assigning field-symbol(<file>).
      call method load_mime_object
        exporting
          object_id            = <file>-objid
          object_url           = <file>-value
        importing
          assigned_url         = l_dummy_url
        exceptions
          object_not_found     = 1
          dp_invalid_parameter = 2
          dp_error_general     = 3
          others               = 4.

      if sy-subrc <> 0.
        raise exception type zcx_html_ui exporting text = |{ <file>-value } load failed with { sy-subrc }|.
      endif.
    endloop.
  endmethod.

  method log_write.
    data l_timestamp type timestampl.
    get time field l_timestamp.
    append value #( stamp = l_timestamp level = level line = str ) to i_log.
  endmethod.

  method log_notice.
    log_write( str = str level = c_loglevel_notice ).
  endmethod.

  method log_warning.
    log_write( str = str level = c_loglevel_warning ).
  endmethod.

  method log_error.
    log_write( str = str level = c_loglevel_error ).
  endmethod.

  method log_critical.
    log_write( str = str level = c_loglevel_critical ).
  endmethod.

  method log_alert.
    log_write( str = str level = c_loglevel_alert ).
  endmethod.

  method log_emergency.
    log_write( str = str level = c_loglevel_emergency ).
  endmethod.

endclass.
