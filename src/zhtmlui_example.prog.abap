*&---------------------------------------------------------------------*
*& Report zhtmlui_example
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
report zhtmlui_example.

class lcl_ui definition inheriting from zcl_bootstrap_ui final.
  public section.
    methods construct redefinition.

  protected section.
    "methods handle_sapevent redefinition.
    methods preload_mime redefinition.
    methods handle_pai for event on_pai_call of lcl_ui importing ucomm.
endclass.

class lcl_ui implementation.
  method construct.
    super->construct( ).
    set handler handle_pai for me.
  endmethod.

  method preload_mime.
    super->preload_mime( ).

    load_binary_data( 'ZHIGHLIGHT%' ).
  endmethod.
*  method handle_sapevent.
*    case action.
*      when others.
*        super->handle_sapevent(
*          action = action
*          query = query
*        ).
*    endcase.
*  endmethod.

  method handle_pai.
    perform pai100 using ucomm.
  endmethod.
endclass.


**********************************************************************
data o_html type ref to lcl_ui.

module pbo100 output.
  set pf-status '100'.
  set titlebar '100'.

  if o_html is initial.
    o_html = new #( parent = cl_gui_custom_container=>screen0 template = conv #( sy-cprog ) ).
    o_html->construct( ).

    o_html->show( ).
  endif.
endmodule.

module pai100 input.
  cl_gui_cfw=>flush( ).
  perform pai100 using sy-ucomm.
endmodule.

form pai100 using ucomm type syst_ucomm.
  case ucomm.
    when 'EXIT'.
      leave program.
    when 'LOGSHOW'.
      o_html->frontent_log_show( ).
    when 'LOGHIDE'.
      o_html->frontend_log_hide( ).
  endcase.
endform.

**********************************************************************
start-of-selection.
  call screen 100.
