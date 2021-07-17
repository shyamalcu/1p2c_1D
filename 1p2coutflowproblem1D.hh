// -*- mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
// vi: set et ts=4 sw=4 sts=4:
/*****************************************************************************
 *   See the file COPYING for full copying permissions.                      *
 *                                                                           *
 *   This program is free software: you can redistribute it and/or modify    *
 *   it under the terms of the GNU General Public License as published by    *
 *   the Free Software Foundation, either version 2 of the License, or       *
 *   (at your option) any later version.                                     *
 *                                                                           *
 *   This program is distributed in the hope that it will be useful,         *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the            *
 *   GNU General Public License for more details.                            *
 *                                                                           *
 *   You should have received a copy of the GNU General Public License       *
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.   *
 *****************************************************************************/
/**
 * \file
 * \brief Definition of a problem, for the 1p2c problem:
 * Component transport of nitrogen dissolved in the water phase.
 */
#ifndef DUMUX_1P2C_OUTFLOW_PROBLEM_1D_HH
#define DUMUX_1P2C_OUTFLOW_PROBLEM_1D_HH

#if HAVE_UG
#include <dune/grid/io/file/dgfparser/dgfug.hh>
#endif
#include <dune/grid/io/file/dgfparser/dgfs.hh>
#include <dune/grid/io/file/dgfparser/dgfyasp.hh>

#include "../1p2ctracermodel/1p2cmodel.hh"
#include <dumux/implicit/common/implicitporousmediaproblem.hh>

#include <dumux/material/fluidsystems/h2on2liquidphasefluidsystem.hh>
#include "1p2coutflowspatialparams01.hh"

namespace Dumux
{

template <class TypeTag>
class OnePTwoCOutflowProblem;

namespace Properties
{
NEW_TYPE_TAG(OnePTwoCOutflowProblem, INHERITS_FROM(OnePTwoC));
NEW_TYPE_TAG(OnePTwoCOutflowBoxProblem, INHERITS_FROM(BoxModel, OnePTwoCOutflowProblem));
NEW_TYPE_TAG(OnePTwoCOutflowCCProblem, INHERITS_FROM(CCModel, OnePTwoCOutflowProblem));

// Set the grid type
SET_PROP(OnePTwoCOutflowProblem, Grid)
{
#if HAVE_UG
    typedef Dune::UGGrid<2> type;
#else
    typedef Dune::SGrid<2, 2> type;
    //typedef Dune::YaspGrid<2> type;
#endif
};

// Set the problem property
SET_PROP(OnePTwoCOutflowProblem, Problem)
{
    typedef Dumux::OnePTwoCOutflowProblem<TypeTag> type;
};

// Set fluid configuration
SET_PROP(OnePTwoCOutflowProblem, FluidSystem)
{ private:
    typedef typename GET_PROP_TYPE(TypeTag, Scalar) Scalar;
public:
    typedef Dumux::FluidSystems::H2ON2LiquidPhase<Scalar, false> type;
};

// Set the spatial parameters
SET_TYPE_PROP(OnePTwoCOutflowProblem,
              SpatialParams,
              Dumux::OnePTwoCOutflowSpatialParams<TypeTag>);

// Define whether mole(true) or mass (false) fractions are used
SET_BOOL_PROP(OnePTwoCOutflowProblem, UseMoles, true);

// Enable velocity output
SET_BOOL_PROP(OnePTwoCOutflowProblem, VtkAddVelocity, true);

// Disable gravity
SET_BOOL_PROP(OnePTwoCOutflowProblem, ProblemEnableGravity, false);
}


/*!
 * \ingroup OnePTwoCBoxModel
 * \ingroup ImplicitTestProblems
 *
 * \brief Definition of a problem, for the 1p2c problem:
 * Nitrogen is dissolved in the water phase and
 * is transported with the water flow from the left side to the right.
 *
 * The model domain is 1 m times 1 m with a discretization length of 0.05 m
 * and homogeneous soil properties (\f$ \mathrm{K=10e-10, \Phi=0.4, \tau=0.28}\f$).
 * Initially the domain is filled with pure water.
 *
 * At the left side, a Dirichlet condition defines a nitrogen mole fraction
 * of 0.3 mol/mol.
 * The water phase flows from the left side to the right due to the applied pressure
 * gradient of 1e5 Pa/m. The nitrogen is transported with the water flow
 * and leaves the domain at the right boundary
 * where an outflow boundary condition is applied.
 * 
 * The model is able to use either mole or mass fractions. The property useMoles can be set to either true or false in the
 * problem file. Make sure that the according units are used in the problem setup. The default setting for useMoles is true.
 *
 * This problem uses the \ref OnePTwoCBoxModel model.
 *
 * To run the simulation execute the following line in shell:
 * <tt>./test_box1p2c -parameterFile ./test_box1p2c.input</tt> or 
 * <tt>./test_cc1p2c -parameterFile ./test_cc1p2c.input</tt>
 */
template <class TypeTag>
class OnePTwoCOutflowProblem : public ImplicitPorousMediaProblem<TypeTag>
{
    typedef ImplicitPorousMediaProblem<TypeTag> ParentType;

    typedef typename GET_PROP_TYPE(TypeTag, GridView) GridView;
    typedef typename GET_PROP_TYPE(TypeTag, Scalar) Scalar;
    typedef typename GET_PROP_TYPE(TypeTag, FVElementGeometry) FVElementGeometry;
    typedef typename GET_PROP_TYPE(TypeTag, PrimaryVariables) PrimaryVariables;
    typedef typename GET_PROP_TYPE(TypeTag, FluidSystem) FluidSystem;
    typedef typename GET_PROP_TYPE(TypeTag, BoundaryTypes) BoundaryTypes;
    typedef typename GET_PROP_TYPE(TypeTag, TimeManager) TimeManager;

    // copy some indices for convenience
    typedef typename GET_PROP_TYPE(TypeTag, Indices) Indices;
    enum {
        // world dimension
        dimWorld = GridView::dimensionworld
    };
    enum {
        // indices of the primary variables
        pressureIdx = Indices::pressureIdx,
        massOrMoleFracIdx = Indices::massOrMoleFracIdx
    };
    enum {
        // index of the transport equation
        transportEqIdx = Indices::transportEqIdx
    };


    typedef typename GridView::template Codim<0>::Entity Element;
    typedef typename GridView::Intersection Intersection;

    typedef Dune::FieldVector<Scalar, dimWorld> GlobalPosition;

    //! property that defines whether mole or mass fractions are used
        static const bool useMoles = GET_PROP_VALUE(TypeTag, UseMoles);

public:
    OnePTwoCOutflowProblem(TimeManager &timeManager, const GridView &gridView)
        : ParentType(timeManager, gridView)
        , eps_(1e-6)
    {
        //initialize fluid system
        FluidSystem::init();

        name_ = GET_RUNTIME_PARAM_FROM_GROUP(TypeTag, 
                                             std::string, 
                                             Problem, 
                                             Name);

        //stateing in the console whether mole or mass fractions are used
        if(!useMoles)
        {
        	std::cout<<"problem uses mass-fractions"<<std::endl;
        }
        else
        {
        	std::cout<<"problem uses mole-fractions"<<std::endl;
        }
        this->timeManager().startNextEpisode(1e5);
    }

    /*!
     * \name Problem parameters
     */
    // \{

    /*!
     * \brief The problem name.
     *
     * This is used as a prefix for files generated by the simulation.
     */
    const char *name() const
    {
        return name_.c_str();
    }

    
    void episodeEnd()
	{
		// Start new episode if episode is over and assign new boundary conditions
		//if(this->timeManager().episodeIndex() ==1 )

		if (this->timeManager().time()<100*86400)
		{
			this->timeManager().startNextEpisode(1e4);
			this->timeManager().setTimeStepSize(1e4);
		}
		else
		{
			this->timeManager().startNextEpisode(1e6);
			this->timeManager().setTimeStepSize(1e5);
		}	
		

	}
    



    /*!
     * \brief Returns the temperature within the domain.
     *
     * This problem assumes a temperature of 20 degrees Celsius.
     */
    Scalar temperature() const
    { return 273.15 + 20; }; // in [K]

    // \}

    /*!
     * \name Boundary conditions
     */
    // \{

    /*!
     * \brief Specifies which kind of boundary condition should be
     *        used for which equation on a given boundary segment.
     *
     * \param values The boundary types for the conservation equations
     * \param globalPos The position for which the bc type should be evaluated
     */
    void boundaryTypesAtPos(BoundaryTypes &values, 
                            const GlobalPosition &globalPos) const
    {
        if(globalPos[0] < eps_ || globalPos[0] > this->bBoxMax()[0] - eps_)
        {
            values.setAllDirichlet();
        }
        else
        {
            values.setAllNeumann();
        }
        
        // outflow condition for the transport equation at right boundary
        if(globalPos[0] > this->bBoxMax()[0] - eps_)
            values.setOutflow(transportEqIdx);
    }

    /*!
     * \brief Evaluate the boundary conditions for a dirichlet
     *        boundary segment.
     *
     * \param values The dirichlet values for the primary variables
     * \param globalPos The position for which the bc type should be evaluated
     *
     * For this method, the \a values parameter stores primary variables.
     */
    void dirichletAtPos(PrimaryVariables &values, const GlobalPosition &globalPos) const
    {
        initial_(values, globalPos);

        //condition for the N2 molefraction at left boundary
        if (globalPos[0] < eps_){
        	values[pressureIdx] = 12.0e+5;
        	values[massOrMoleFracIdx] = 1.0;

        }
        else if (globalPos[0] > this->bBoxMax()[0] - eps_)
        {
        	values[pressureIdx] = 10.0e+5;
        	values[massOrMoleFracIdx] = 0.0;
        }
    }

    /*!
     * \brief Evaluate the boundary conditions for a Neumann
     *        boundary segment.
     *
     * For this method, the \a priVars parameter stores the mass flux
     * in normal direction of each component. Negative values mean
     * influx.
     *
     * The units must be according to either using mole or mass fractions. (mole/(m^2*s) or kg/(m^2*s))
     */
    void neumann(PrimaryVariables &priVars,
                 const Element &element,
                 const FVElementGeometry &fvGeometry,
                 const Intersection &intersection,
                 const int scvIdx,
                 const int boundaryFaceIdx) const
    {
        priVars = 0;
    }

    // \}

    /*!
     * \name Volume terms
     */
    // \{

    /*!
     * \brief Evaluate the source term for all phases within a given
     *        sub-control-volume.
     *
     * For this method, the \a priVars parameter stores the rate mass
     * of a component is generated or annihilate per volume
     * unit. Positive values mean that mass is created, negative ones
     * mean that it vanishes.
     *
     * The units must be according to either using mole or mass fractions. (mole/(m^3*s) or kg/(m^3*s))
     */
    void sourceAtPos(PrimaryVariables &priVars,
                     const GlobalPosition &globalPos) const
    {
        priVars = Scalar(0.0);
    }

    /*!
     * \brief Evaluate the initial value for a control volume.
     *
     * \param values The initial values for the primary variables
     * \param globalPos The position for which the initial condition should be evaluated
     *
     * For this method, the \a values parameter stores primary
     * variables.
     */
    void initialAtPos(PrimaryVariables &values, const GlobalPosition &globalPos) const
    {
        initial_(values, globalPos);
    }

    // \}

private:
    // the internal method for the initial condition
    void initial_(PrimaryVariables &priVars,
                  const GlobalPosition &globalPos) const
    {
        priVars[pressureIdx] = 10e5; // - 1e5*globalPos[0]; // initial condition for the pressure
        priVars[massOrMoleFracIdx] = 0.0;  // initial condition for the N2 molefraction
    }

    const Scalar eps_;
    std::string name_;
};

} //end namespace
#endif
