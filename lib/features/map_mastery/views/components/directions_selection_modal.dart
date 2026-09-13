import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/directions/directions_cubit.dart';
import '../../logic/directions/directions_state.dart';
import '../../logic/search_places/search_places_cubit.dart';
import '../../logic/search_places/search_places_state.dart';
import '../../data/models/route_direction_model.dart';
import '../../data/models/place_prediction_model.dart';

enum _ActiveSearchField { none, origin, destination }

class DirectionsSelectionModal extends StatefulWidget {
  final bool fetchRoutesOnInit;
  const DirectionsSelectionModal({super.key, this.fetchRoutesOnInit = false});

  @override
  State<DirectionsSelectionModal> createState() =>
      _DirectionsSelectionModalState();
}

class _DirectionsSelectionModalState extends State<DirectionsSelectionModal> {
  final _originController = TextEditingController();
  final _destController = TextEditingController();
  final _originFocus = FocusNode();
  final _destFocus = FocusNode();
  _ActiveSearchField _activeField = _ActiveSearchField.none;

  @override
  void initState() {
    super.initState();
    _originFocus.addListener(_onFocusChange);
    _destFocus.addListener(_onFocusChange);

    // Set initial values from Cubit
    final dirCubit = context.read<DirectionsCubit>();
    final state = dirCubit.state;
    _originController.text = state.origin?.name ?? 'Your location';
    _destController.text = state.destination?.name ?? '';
    
    // Automatically fetch routes on init if both origin and destination are present
    if (widget.fetchRoutesOnInit && state.origin != null && state.destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          dirCubit.fetchAllRoutes();
        }
      });
    }
  }

  @override
  void dispose() {
    _originFocus.removeListener(_onFocusChange);
    _destFocus.removeListener(_onFocusChange);
    _originController.dispose();
    _destController.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_originFocus.hasFocus) {
      setState(() => _activeField = _ActiveSearchField.origin);
      _originController.clear();
      context.read<SearchPlacesCubit>().onQueryChanged('');
    } else if (_destFocus.hasFocus) {
      setState(() => _activeField = _ActiveSearchField.destination);
      _destController.clear();
      context.read<SearchPlacesCubit>().onQueryChanged('');
    } else {
      setState(() => _activeField = _ActiveSearchField.none);
    }
  }

  void _syncControllers() {
    final state = context.read<DirectionsCubit>().state;
    if (_activeField != _ActiveSearchField.origin) {
      _originController.text = state.origin?.name ?? 'Your location';
    }
    if (_activeField != _ActiveSearchField.destination) {
      _destController.text = state.destination?.name ?? '';
    }
  }

  Future<void> _onPredictionTapped(PlacePredictionModel prediction) async {
    final searchCubit = context.read<SearchPlacesCubit>();
    final dirCubit = context.read<DirectionsCubit>();

    final details = await searchCubit.selectPrediction(prediction.placeId);
    if (details != null) {
      if (_activeField == _ActiveSearchField.origin) {
        dirCubit.setOrigin(details);
        _originFocus.unfocus();
      } else if (_activeField == _ActiveSearchField.destination) {
        dirCubit.setDestination(details);
        _destFocus.unfocus();
      }
      _syncControllers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DirectionsCubit, DirectionsState>(
      listenWhen: (prev, current) =>
          prev.origin != current.origin ||
          prev.destination != current.destination,
      listener: (context, state) => _syncControllers(),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildInputSection(),
              if (_activeField != _ActiveSearchField.none)
                Expanded(child: _buildPredictionsList())
              else
                Expanded(child: _buildModesSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Directions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _originController,
                  focusNode: _originFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.my_location, size: 20),
                    hintText: 'Choose starting point',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) =>
                      context.read<SearchPlacesCubit>().onQueryChanged(val),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _destController,
                  focusNode: _destFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.location_on,
                      size: 20,
                      color: Colors.red,
                    ),
                    hintText: 'Choose destination',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) =>
                      context.read<SearchPlacesCubit>().onQueryChanged(val),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert),
            onPressed: () {
              context.read<DirectionsCubit>().swapOriginDestination();
              _syncControllers();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsList() {
    return BlocBuilder<SearchPlacesCubit, SearchPlacesState>(
      builder: (context, state) {
        if (state.status == SearchStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == SearchStatus.empty) {
          return const Center(child: Text('No results found.'));
        }
        return ListView.builder(
          itemCount: state.predictions.length,
          itemBuilder: (context, index) {
            final pred = state.predictions[index];
            return ListTile(
              leading: const Icon(Icons.place, color: Colors.grey),
              title: Text(pred.primaryText),
              subtitle: Text(pred.secondaryText, maxLines: 1),
              onTap: () => _onPredictionTapped(pred),
            );
          },
        );
      },
    );
  }

  Widget _buildModesSection() {
    return BlocBuilder<DirectionsCubit, DirectionsState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.read<DirectionsCubit>().fetchAllRoutes();
                },
                child: const Text('Fetch Routes'),
              ),
            ),
            const SizedBox(height: 16),
            if (state.status == DirectionsStatus.loading)
              const Center(child: CircularProgressIndicator())
            else if (state.status == DirectionsStatus.invalidInput)
              Center(
                child: Text(
                  state.errorMessage ?? '',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (state.status == DirectionsStatus.ready) ...[
              _buildModeTile(
                context,
                state,
                TravelMode.driving,
                Icons.directions_car,
              ),
              _buildModeTile(
                context,
                state,
                TravelMode.twoWheeler,
                Icons.two_wheeler,
              ),
              _buildModeTile(
                context,
                state,
                TravelMode.transit,
                Icons.directions_transit,
              ),
              _buildModeTile(
                context,
                state,
                TravelMode.walking,
                Icons.directions_walk,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildModeTile(
    BuildContext context,
    DirectionsState state,
    TravelMode mode,
    IconData icon,
  ) {
    final result = state.modeResults[mode];
    final isSelected = state.selectedMode == mode;

    Widget trailing;
    String title = mode.name.toUpperCase();

    if (result is RouteReady) {
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            result.route.durationInTrafficText ?? result.route.durationText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            result.route.distanceText,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      );
    } else if (result is RouteFailed) {
      trailing = const Text('Unavailable', style: TextStyle(color: Colors.red));
    } else if (result is RouteLoading) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = const SizedBox();
    }

    return Card(
      color: isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
          : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: trailing,
        onTap: () {
          if (result is RouteReady) {
            context.read<DirectionsCubit>().selectMode(mode);
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
