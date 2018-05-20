class zcx_html_ui definition public inheriting from cx_no_check create public.
  public section.

    methods constructor
      importing
        previous like previous optional
        text     type string
        id       type i default 0.

    methods if_message~get_longtext redefinition.
    methods if_message~get_text redefinition.
    methods get_id returning value(ret) type i.

  protected section.

    data:
      exception_id      type i,
      exception_message type string.

endclass.



class zcx_html_ui implementation.

  method constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid = textid previous = previous ).
    exception_message = text.
    exception_id = id.
  endmethod.


  method if_message~get_longtext.
    data:
      program_name type syrepid,
      include_name type syrepid,
      source_line  type i.

    get_source_position(
      importing
        program_name = program_name
        include_name = include_name
        source_line  = source_line
    ).
    result = |[{ program_name }] { include_name }:{ source_line } { exception_message }|.
  endmethod.


  method if_message~get_text.
    result = exception_message.
  endmethod.

  method get_id.
    ret = exception_id.
  endmethod.

endclass.
