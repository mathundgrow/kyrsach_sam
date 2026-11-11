import 'dart:isolate';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/class_node.dart';
import '../models/class_relation.dart';
import '../services/project_scanner.dart';

// --- СОБЫТИЯ (Events) ---
abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

class AnalyzeProject extends ProjectEvent {
  final String path;
  const AnalyzeProject(this.path);
  @override
  List<Object?> get props => [path];
}

class SelectNode extends ProjectEvent {
  final ClassNode? node;
  const SelectNode(this.node);
  @override
  List<Object?> get props => [node];
}

// --- СОСТОЯНИЯ (States) ---
abstract class ProjectState extends Equatable {
  const ProjectState();
  @override
  List<Object?> get props => [];
}

class ProjectInitial extends ProjectState {}

class ProjectLoading extends ProjectState {}

class ProjectError extends ProjectState {
  final String message;
  const ProjectError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProjectLoaded extends ProjectState {
  final List<ClassNode> nodes;
  final List<ClassRelation> relations;
  final int filesCount;
  final ClassNode? selectedNode;
  final Set<String> anomalyNodeIds;
  final int healthScore;

  const ProjectLoaded({
    required this.nodes,
    required this.relations,
    required this.filesCount,
    this.selectedNode,
    this.anomalyNodeIds = const {},
    this.healthScore = 100,
  });

  @override
  List<Object?> get props => [
        nodes,
        relations,
        filesCount,
        selectedNode,
        anomalyNodeIds,
        healthScore,
      ];
}

// --- САМ BLOC (Мозг) ---
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectScanner _scanner = ProjectScanner();

  ProjectBloc() : super(ProjectInitial()) {
    on<AnalyzeProject>((event, emit) async {
      emit(ProjectLoading());
      
      try {
        // 1. Сканируем проект
        final (nodes, relations, filesCount) = await _scanner.scanProject(event.path);

        // 2. ИЩЕМ АНОМАЛИИ
        final incomingCounts = <String, int>{};
        for (final rel in relations) {
          incomingCounts[rel.toClassId] = (incomingCounts[rel.toClassId] ?? 0) + 1;
        }
        final anomalies = <String>{};
        incomingCounts.forEach((id, count) {
          if (count >= 3) anomalies.add(id);
        });

        // 3. СЧИТАЕМ ЗДОРОВЬЕ
        final connectedNodes = <String>{};
        for (final rel in relations) {
          connectedNodes.add(rel.fromClassId);
          connectedNodes.add(rel.toClassId);
        }
        
        int isolatedCount = 0;
        for (final node in nodes) {
          if (!connectedNodes.contains(node.id)) isolatedCount++;
        }

        int score = 100 - (anomalies.length * 10) - (isolatedCount * 2);
        if (score < 0) score = 0;

        // 4. Отправляем данные в UI
        emit(ProjectLoaded(
          nodes: nodes,
          relations: relations,
          filesCount: filesCount,
          anomalyNodeIds: anomalies,
          healthScore: score,
        ));
      } catch (e) {
        emit(ProjectError(e.toString()));
      }
    });

    on<SelectNode>((event, emit) {
      if (state is ProjectLoaded) {
        final currentState = state as ProjectLoaded;
        emit(ProjectLoaded(
          nodes: currentState.nodes,
          relations: currentState.relations,
          filesCount: currentState.filesCount,
          selectedNode: event.node,
          anomalyNodeIds: currentState.anomalyNodeIds,
          healthScore: currentState.healthScore, // Обязательно сохраняем здоровье!
        ));
      }
    });
  }
}