// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daos.dart';

// ignore_for_file: type=lint
mixin _$ProfilesDaoMixin on DatabaseAccessor<WarangDatabase> {
  $ProfilesTable get profiles => attachedDatabase.profiles;
  ProfilesDaoManager get managers => ProfilesDaoManager(this);
}

class ProfilesDaoManager {
  final _$ProfilesDaoMixin _db;
  ProfilesDaoManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
}

mixin _$TripsDaoMixin on DatabaseAccessor<WarangDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  TripsDaoManager get managers => TripsDaoManager(this);
}

class TripsDaoManager {
  final _$TripsDaoMixin _db;
  TripsDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
}

mixin _$MomentsDaoMixin on DatabaseAccessor<WarangDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $MomentsTable get moments => attachedDatabase.moments;
  MomentsDaoManager get managers => MomentsDaoManager(this);
}

class MomentsDaoManager {
  final _$MomentsDaoMixin _db;
  MomentsDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$MomentsTableTableManager get moments =>
      $$MomentsTableTableManager(_db.attachedDatabase, _db.moments);
}

mixin _$PhotosDaoMixin on DatabaseAccessor<WarangDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $MomentsTable get moments => attachedDatabase.moments;
  $PhotosTable get photos => attachedDatabase.photos;
  PhotosDaoManager get managers => PhotosDaoManager(this);
}

class PhotosDaoManager {
  final _$PhotosDaoMixin _db;
  PhotosDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$MomentsTableTableManager get moments =>
      $$MomentsTableTableManager(_db.attachedDatabase, _db.moments);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
}

mixin _$AppMetaDaoMixin on DatabaseAccessor<WarangDatabase> {
  $AppMetaTable get appMeta => attachedDatabase.appMeta;
  AppMetaDaoManager get managers => AppMetaDaoManager(this);
}

class AppMetaDaoManager {
  final _$AppMetaDaoMixin _db;
  AppMetaDaoManager(this._db);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db.attachedDatabase, _db.appMeta);
}

mixin _$SearchDaoMixin on DatabaseAccessor<WarangDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $MomentsTable get moments => attachedDatabase.moments;
  SearchDaoManager get managers => SearchDaoManager(this);
}

class SearchDaoManager {
  final _$SearchDaoMixin _db;
  SearchDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$MomentsTableTableManager get moments =>
      $$MomentsTableTableManager(_db.attachedDatabase, _db.moments);
}
