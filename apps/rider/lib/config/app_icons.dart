import 'package:flutter/material.dart';

/// Centralized icon constants replacing emoji text strings throughout the app.
///
/// Usage:
/// ```dart
/// Icon(AppIcons.bike, color: AppColors.green)
/// ```
class AppIcons {
  AppIcons._();

  // ── Services ──────────────────────────────────────────────
  static const IconData bike = Icons.two_wheeler;
  static const IconData car = Icons.directions_car;
  static const IconData food = Icons.restaurant;
  static const IconData designatedDriver = Icons.car_rental;
  static const IconData grocery = Icons.shopping_cart;
  static const IconData delivery = Icons.local_shipping;
  static const IconData schedule = Icons.schedule;
  static const IconData activities = Icons.list_alt;

  // ── Navigation ────────────────────────────────────────────
  static const IconData home = Icons.home_rounded;
  static const IconData history = Icons.receipt_long_rounded;
  static const IconData wallet = Icons.account_balance_wallet_rounded;
  static const IconData chat = Icons.chat_bubble_rounded;
  static const IconData profile = Icons.person_rounded;
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData myLocation = Icons.my_location_rounded;
  static const IconData target = Icons.gps_fixed_rounded;

  // ── Actions ───────────────────────────────────────────────
  static const IconData call = Icons.phone_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.chevron_right_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData camera = Icons.camera_alt_rounded;
  static const IconData share = Icons.share_rounded;

  // ── Status ────────────────────────────────────────────────
  static const IconData online = Icons.wifi_rounded;
  static const IconData offline = Icons.wifi_off_rounded;
  static const IconData radar = Icons.radar_rounded;
  static const IconData shield = Icons.shield_rounded;
  static const IconData verified = Icons.verified_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData fire = Icons.local_fire_department_rounded;
  static const IconData trophy = Icons.emoji_events_rounded;

  // ── Ride Related ──────────────────────────────────────────
  static const IconData pickup = Icons.trip_origin_rounded;
  static const IconData dropoff = Icons.location_on_rounded;
  static const IconData route = Icons.route_rounded;
  static const IconData speed = Icons.speed_rounded;
  static const IconData distance = Icons.straighten_rounded;
  static const IconData timer = Icons.timer_rounded;

  // ── Payment ───────────────────────────────────────────────
  static const IconData cash = Icons.payments_rounded;
  static const IconData creditCard = Icons.credit_card_rounded;
  static const IconData voucher = Icons.confirmation_number_rounded;
  static const IconData topUp = Icons.add_card_rounded;

  // ── Driver ────────────────────────────────────────────────
  static const IconData steering = Icons.settings_rounded;
  static const IconData earnings = Icons.trending_up_rounded;
  static const IconData trips = Icons.check_circle_rounded;
  static const IconData rating = Icons.star_half_rounded;
  static const IconData acceptance = Icons.thumb_up_rounded;
  static const IconData hotspot = Icons.local_fire_department_rounded;
  static const IconData vehicle = Icons.directions_car_filled_rounded;
  static const IconData license = Icons.badge_rounded;

  // ── Misc ──────────────────────────────────────────────────
  static const IconData sos = Icons.sos_rounded;
  static const IconData support = Icons.support_agent_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData privacy = Icons.privacy_tip_rounded;
  static const IconData terms = Icons.description_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData swap = Icons.swap_horiz_rounded;
  static const IconData pin = Icons.push_pin_rounded;
  static const IconData note = Icons.sticky_note_2_rounded;
}
