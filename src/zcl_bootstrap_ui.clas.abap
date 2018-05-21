class zcl_bootstrap_ui definition public inheriting from zcl_html_ui create public.
  protected section.
    methods preload_mime redefinition.
endclass.



class zcl_bootstrap_ui implementation.
  method preload_mime.
    super->preload_mime( ).
    load_binary_data( 'ZBP4_1_1_%' ).
  endmethod.
endclass.
