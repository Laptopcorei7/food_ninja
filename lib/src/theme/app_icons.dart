import 'package:flutter/widgets.dart';

/// The kit's outline icons, cut from `new_designs/components/`. Each is a
/// white mask, so `ImageIcon(AppIcons.bell, color: ...)` paints it any colour.
abstract final class AppIcons {
  static const _dir = 'assets/icons';

  static const logoMark = AssetImage('$_dir/logo_mark.png');

  // bottom nav
  static const navHome = AssetImage('$_dir/nav_home.png');
  static const navMenu = AssetImage('$_dir/nav_menu.png');
  static const navFavorites = AssetImage('$_dir/nav_favorites.png');
  static const navOrders = AssetImage('$_dir/nav_orders.png');
  static const navSupport = AssetImage('$_dir/nav_support.png');

  // food categories, outline and filled (selected)
  static const catSnacks = AssetImage('$_dir/cat_snacks.png');
  static const catMeal = AssetImage('$_dir/cat_meal.png');
  static const catVegan = AssetImage('$_dir/cat_vegan.png');
  static const catDessert = AssetImage('$_dir/cat_dessert.png');
  static const catDrinks = AssetImage('$_dir/cat_drinks.png');
  static const catSnacksFilled = AssetImage('$_dir/cat_snacks_filled.png');
  static const catMealFilled = AssetImage('$_dir/cat_meal_filled.png');
  static const catVeganFilled = AssetImage('$_dir/cat_vegan_filled.png');
  static const catDessertFilled = AssetImage('$_dir/cat_dessert_filled.png');
  static const catDrinksFilled = AssetImage('$_dir/cat_drinks_filled.png');

  static const alert = AssetImage('$_dir/alert.png');
  static const apple = AssetImage('$_dir/apple.png');
  static const attach = AssetImage('$_dir/attach.png');
  static const bag = AssetImage('$_dir/bag.png');
  static const bell = AssetImage('$_dir/bell.png');
  static const camera = AssetImage('$_dir/camera.png');
  static const card = AssetImage('$_dir/card.png');
  static const cart = AssetImage('$_dir/cart.png');
  static const chat = AssetImage('$_dir/chat.png');
  static const checkCircle = AssetImage('$_dir/check_circle.png');
  static const clock = AssetImage('$_dir/clock.png');
  static const closeCircle = AssetImage('$_dir/close_circle.png');
  static const discount = AssetImage('$_dir/discount.png');
  static const edit = AssetImage('$_dir/edit.png');
  static const eye = AssetImage('$_dir/eye.png');
  static const eyeOff = AssetImage('$_dir/eye_off.png');
  static const facebook = AssetImage('$_dir/facebook.png');
  static const filter = AssetImage('$_dir/filter.png');
  static const google = AssetImage('$_dir/google.png');
  static const googlePlay = AssetImage('$_dir/google_play.png');
  static const headset = AssetImage('$_dir/headset.png');
  static const heart = AssetImage('$_dir/heart.png');
  static const home = AssetImage('$_dir/home.png');
  static const image = AssetImage('$_dir/image.png');
  static const instagram = AssetImage('$_dir/instagram.png');
  static const location = AssetImage('$_dir/location.png');
  static const lock = AssetImage('$_dir/lock.png');
  static const logOut = AssetImage('$_dir/log_out.png');
  static const mail = AssetImage('$_dir/mail.png');
  static const map = AssetImage('$_dir/map.png');
  static const mic = AssetImage('$_dir/mic.png');
  static const orderSwap = AssetImage('$_dir/order_swap.png');
  static const paypal = AssetImage('$_dir/paypal.png');
  static const phone = AssetImage('$_dir/phone.png');
  static const rider = AssetImage('$_dir/rider.png');
  static const send = AssetImage('$_dir/send.png');
  static const settings = AssetImage('$_dir/settings.png');
  static const share = AssetImage('$_dir/share.png');
  static const trash = AssetImage('$_dir/trash.png');
  static const user = AssetImage('$_dir/user.png');
  static const utensils = AssetImage('$_dir/utensils.png');
  static const website = AssetImage('$_dir/website.png');
  static const whatsapp = AssetImage('$_dir/whatsapp.png');
}
