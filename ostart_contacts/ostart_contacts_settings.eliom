(* This file was generated by Ocsigen Start.
   Feel free to use it, modify it, and redistribute it as you wish. *)

let%shared update_main_email_button email =
  let open Eliom_content.Html in
  let button =
    D.button ~a:[D.a_class ["button"]]
      [D.pcdata [%i18n S.set_as_main_email ~capitalize:true]]
  in
  ignore [%client (Lwt.async (fun () ->
    Lwt_js_events.clicks
      (Eliom_content.Html.To_dom.of_element ~%button)
      (fun _ _ ->
        let%lwt () = Os_current_user.update_main_email ~%email in
        Eliom_client.change_page
          ~service:Ostart_contacts_services.settings_service () ()
      )
  ) : unit) ];
  button

(* A button to remove the email from the database *)
let%shared delete_email_button email =
  let open Eliom_content.Html in
  let button = D.button
      ~a:[D.a_class ["button" ; "os-remove-email-button"]]
      [Ostart_contacts_icons.D.trash ()]
  in
  ignore [%client (Lwt.async (fun () ->
    Lwt_js_events.clicks
      (Eliom_content.Html.To_dom.of_element ~%button)
      (fun _ _ ->
        let%lwt () = Os_current_user.remove_email_from_user ~%email in
        Eliom_client.change_page
          ~service:Ostart_contacts_services.settings_service () ()
      )
  ) : unit) ];
  button

(* A list of buttons to update or to remove the email depending on the
   email properties *)
let%shared buttons_of_email is_main_email is_validated email =
  if is_main_email
  then []
  else if is_validated
  then [update_main_email_button email ; delete_email_button email]
  else [delete_email_button email]

(* A list of labels describing the email properties. *)
let%shared labels_of_email is_main_email is_validated =
  let open Eliom_content.Html.F in
  let valid_label =
    span ~a: [a_class ["os-settings-label" ; "os-validated-email"]] [
     pcdata @@
      if is_validated
      then [%i18n S.validated ~capitalize:true]
      else [%i18n S.waiting_confirmation ~capitalize:true]
  ] in
  if is_main_email
  then [ span ~a:[a_class ["os-settings-label" ; "os-main-email"]]
           [%i18n main_email ~capitalize:true]
       ; valid_label]
  else [ valid_label ]

(* List element for the given email *)
let%shared li_of_email main_email (email, is_validated) =
  let open Eliom_content.Html.D in
  let is_main_email = (main_email = email) in
  let labels = labels_of_email is_main_email is_validated in
  let buttons = buttons_of_email is_main_email is_validated email in
  let email = span ~a:[a_class ["os-settings-email"]] [pcdata email] in
  Lwt.return @@ li (email :: labels @ buttons)

let%shared ul_of_emails (main_email, emails) =
  let open Eliom_content.Html.F in
  let li_of_email = li_of_email main_email in
  let%lwt li_list = Lwt_list.map_s li_of_email emails in
  Lwt.return @@ ul li_list

(* List with information about emails *)
let%server get_emails () =
  let myid = Os_current_user.get_current_userid () in
  let%lwt main_email = Os_db.User.email_of_userid myid in
  let%lwt emails = Os_db.User.emails_of_userid myid in
  let%lwt emails = Lwt_list.map_s
      (fun email ->
         let%lwt v = Os_current_user.is_email_validated email in
         Lwt.return (email, v))
      emails
  in
  Lwt.return (main_email, emails)

(* List with information about emails *)
let%client get_emails =
  ~%(Eliom_client.server_function [%derive.json : unit]
       (Os_session.connected_wrapper get_emails))

let%shared select_language_form =
  (fun select_language_name ->
     let open Eliom_content.Html in
     let current_language = Ostart_contacts_i18n.get_language () in
     let all_languages_except_current =
       List.filter
         (fun l -> l <> current_language)
         Ostart_contacts_i18n.languages
     in
     let form_option_of_language language is_current_language =
       D.Form.Option (
         [], (* No attributes *)
         Ostart_contacts_i18n.string_of_language language,
         None,
         is_current_language
       )
     in
     [ D.p [D.pcdata [%i18n S.change_language]]
     ; D.Form.select
         ~name:select_language_name
         D.Form.string
         (form_option_of_language current_language true)
         (List.map
            (fun l -> form_option_of_language l false)
            all_languages_except_current
         )
     ; D.Form.input
         ~input_type:`Submit
         ~value:[%i18n S.send ~capitalize:true]
         D.Form.string
     ]
  )

let%shared settings_content () =
  let%lwt emails = get_emails () in
  let%lwt emails = ul_of_emails emails in
  Lwt.return @@
  Eliom_content.Html.D.(
    [
      div ~a:[a_class ["os-settings"]] [
        p [%i18n change_password ~capitalize:true];
        Os_user_view.password_form
          ~a_placeholder_pwd:[%i18n S.password]
          ~a_placeholder_confirmation:[%i18n S.retype_password]
          ~text_send_button:[%i18n S.send]
          ~service:Os_services.set_password_service ();
        br ();
        Os_user_view.upload_pic_link
          ~submit:([a_class ["button"]], [pcdata "Submit"])
          ~content:[%i18n change_profile_picture]
          Ostart_contacts_services.upload_user_avatar_service;
        br ();
        Os_user_view.reset_tips_link
          ~text_link:[%i18n S.see_help_again_from_beginning]
          ();
        br ();
        p [%i18n link_new_email];
        Os_user_view.generic_email_form
          ~a_placeholder_email:[%i18n S.email_address]
          ~text:[%i18n S.send]
          ~service:Os_services.add_email_service
          ();
        p [%i18n currently_registered_emails];
        div ~a:[a_class ["os-emails"]] [emails];
        Form.post_form
          ~service:Os_services.update_language_service
          select_language_form
          ()
      ]
    ]
  )
