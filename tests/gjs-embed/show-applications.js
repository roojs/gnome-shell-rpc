import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

const connection = Gio.bus_get_sync(Gio.BusType.SESSION, null);
connection.call_sync(
    'org.freedesktop.DBus',
    '/org/freedesktop/DBus',
    'org.freedesktop.DBus',
    'RequestName',
    new GLib.Variant('(su)', ['org.gnome.Settings', 0]),
    new GLib.VariantType('(u)'),
    Gio.DBusCallFlags.NONE,
    -1,
    null);
connection.call_sync(
    'org.gnome.Shell',
    '/org/gnome/Shell',
    'org.gnome.Shell',
    'ShowApplications',
    null,
    null,
    Gio.DBusCallFlags.NONE,
    -1,
    null);
print('show-applications: requested');
