package pt.unl.fct.di.apdc.trailblaze.util;

public class UpdateTrailRequest {
    public String observation;

    public boolean hasValidObservation() {
        return observation != null && !observation.trim().isEmpty();
    }
}