import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'resource_removal.dart';

Future<bool> confirmWorkspaceDeletion(
  BuildContext context,
  ApiClient api, {
  required String id,
  required String name,
}) =>
    confirmResourceRemoval(context, api, kind: 'workspace', id: id, name: name);
Future<bool> confirmOrganizationDeletion(
  BuildContext context,
  ApiClient api, {
  required String id,
  required String name,
}) => confirmResourceRemoval(
  context,
  api,
  kind: 'organization',
  id: id,
  name: name,
);
