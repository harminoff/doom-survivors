// P020 source-ground-plane boundary.
//
// The locked engineering transform is fp-ground-v1: source and engine axes
// share orientation, the origin is explicit, and k is one reference unit per
// engine unit. Gameplay owns X/Y; visual Z is an adapter concern.
struct DSP020GroundPoint
{
    double x;
    double y;
}

class DSP020GroundPlane
{
    const TRANSFORM_ID = "fp-ground-v1";
    const SCALE = 1.0;

    static void ToEngine(double sourceX, double sourceY,
                         double originX, double originY,
                         out double engineX, out double engineY)
    {
        engineX = (sourceX - originX) * SCALE;
        engineY = (sourceY - originY) * SCALE;
    }

    static void ToSource(double engineX, double engineY,
                         double originX, double originY,
                         out double sourceX, out double sourceY)
    {
        sourceX = engineX / SCALE + originX;
        sourceY = engineY / SCALE + originY;
    }
}
